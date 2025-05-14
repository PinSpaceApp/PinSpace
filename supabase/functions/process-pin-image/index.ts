// supabase/functions/process-pin-image/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"; // Using a common recent version
// Import djwt for creating and signing JWTs
// Ensure you are using a version of djwt compatible with your Deno version.
// Check https://deno.land/x/djwt for the latest.
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

console.log("Process Pin Image Edge Function starting...");

// Interface for the structure of Google Service Account Credentials JSON
interface GoogleServiceAccountCredentials {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string; // This is the PEM formatted private key
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string; // e.g., "https://oauth2.googleapis.com/token"
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
  universe_domain?: string; // Optional, present in newer keys
}

// Helper function to convert PEM string (from Google JSON) to ArrayBuffer for Web Crypto API
function pemToBinary(pem: string): ArrayBuffer {
  // Remove PEM header and footer
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = pem.substring(pemHeader.length, pem.indexOf(pemFooter)).trim();
  // Remove newlines and decode base64
  const binaryString = atob(pemContents.replace(/\n/g, ''));
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

// Function to get Google Access Token using Service Account credentials
async function getGoogleAccessToken(credentialsJsonString: string): Promise<string> {
  console.log("Attempting to get Google Access Token...");
  const credentials = JSON.parse(credentialsJsonString) as GoogleServiceAccountCredentials;

  const privateKeyPem = credentials.private_key;

  // Import the private key for signing using Web Crypto API
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", // Format of the key (PKCS#8 is standard for Google's PEM)
    pemToBinary(privateKeyPem), // Convert PEM string to ArrayBuffer
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, // Algorithm details for RS256
    false, // The key is not extractable
    ["sign"] // Key usage: only for signing
  );

  const nowInSeconds = Math.floor(Date.now() / 1000);
  const expirationInSeconds = nowInSeconds + 3599; // Token valid for just under 1 hour

  // Create JWT payload (claims)
  const payload = {
    iss: credentials.client_email, // Issuer: service account email
    scope: "https://www.googleapis.com/auth/cloud-vision", // Scope for Vision API
    aud: credentials.token_uri,    // Audience: Google OAuth2 token endpoint
    exp: expirationInSeconds,      // Expiration time (NumericDate)
    iat: nowInSeconds,             // Issued at time (NumericDate)
  };

  // Create and sign the JWT
  // Header for RS256
  const jwtHeader = { alg: "RS256" as const, typ: "JWT" };
  const jwt = await create(jwtHeader, payload, cryptoKey);

  console.log("JWT created. Requesting access token from Google...");

  // Request the access token from Google's token endpoint
  const tokenResponse = await fetch(credentials.token_uri, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }).toString(), // URLSearchParams automatically encodes
  });

  const tokenDataText = await tokenResponse.text(); // Get text for robust error logging
  if (!tokenResponse.ok) {
    console.error("Failed to get access token from Google:", tokenResponse.status, tokenDataText);
    throw new Error(`Google Auth Error: ${tokenResponse.status} ${tokenDataText}`);
  }

  const tokenData = JSON.parse(tokenDataText);
  if (!tokenData.access_token) {
    console.error("Access token not found in Google's response:", tokenData);
    throw new Error("Access token not found in response from Google.");
  }

  console.log("Successfully obtained Google Access Token.");
  return tokenData.access_token;
}


serve(async (req: Request) => {
  // Standard CORS preflight handling
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*", // Be more specific in production
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: "Method Not Allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }

  let imageDataBase64: string;
  try {
    const body = await req.json();
    imageDataBase64 = body.imageData; // Expecting { "imageData": "base64string..." }
    if (!imageDataBase64 || typeof imageDataBase64 !== 'string') {
      throw new Error("Missing or invalid imageData (must be a base64 string) in request body");
    }
  } catch (error) {
    console.error("Invalid request body:", error);
    return new Response(JSON.stringify({ error: "Invalid request body: " + error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }

  const gcpCredentialsJsonString = Deno.env.get("GOOGLE_VISION_API_CREDENTIALS");
  if (!gcpCredentialsJsonString) {
    console.error("CRITICAL: GOOGLE_VISION_API_CREDENTIALS secret not found in Supabase.");
    return new Response(JSON.stringify({ error: "Server configuration error: GCP credentials secret not found" }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }

  try {
    const accessToken = await getGoogleAccessToken(gcpCredentialsJsonString);

    const visionApiUrl = `https://vision.googleapis.com/v1/images:annotate`;
    const visionApiPayload = {
      requests: [
        {
          image: { content: imageDataBase64 },
          features: [
            { type: "WEB_DETECTION", maxResults: 10 }, // For similar images and web entities
            { type: "LABEL_DETECTION", maxResults: 5 },  // For general object labels
            // { type: "OBJECT_LOCALIZATION", maxResults: 1 }, // If you want to find the pin bounding box
          ],
        },
      ],
    };

    console.log("Calling Google Vision API...");
    const visionResponse = await fetch(visionApiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify(visionApiPayload),
    });

    console.log("Google Vision API response status:", visionResponse.status);
    const visionDataText = await visionResponse.text(); // Read as text for better error diagnosis

    if (!visionResponse.ok) {
      console.error("Vision API Error Response Body:", visionDataText);
      throw new Error(`Vision API call failed: ${visionResponse.status} ${visionDataText}`);
    }

    const visionData = JSON.parse(visionDataText);
    console.log("Vision API Raw Response:", JSON.stringify(visionData, null, 2).substring(0, 500) + "..."); // Log snippet

    // --- Process visionData to extract relevant info ---
    const firstResponse = visionData.responses?.[0];
    if (!firstResponse) {
      throw new Error("No response found in Vision API output.");
    }
    
    const webDetection = firstResponse.webDetection;
    const labelAnnotations = firstResponse.labelAnnotations;

    const suggestedUrlsFromVision = webDetection?.visuallySimilarImages
        ?.map((img: any) => img.url as string)
        .filter((url?: string) => url != null) ?? [];

    const labelsFromVision = labelAnnotations // Prefer more general labels if webEntities are too broad
        ?.map((label: any) => label.description as string)
        .filter((desc?: string) => desc != null) ?? [];
    
    const webEntities = webDetection?.webEntities
        ?.map((entity: any) => entity.description as string)
        .filter((desc?: string) => desc != null) ?? [];

    // Combine labels and web entities for a richer identified name, prioritizing web entities if available
    let identifiedName = "Unknown Pin";
    if (webEntities.length > 0) {
      identifiedName = webEntities[0]; // Often more specific
    } else if (labelsFromVision.length > 0) {
      identifiedName = labelsFromVision[0];
    }
    
    const finalSuggestedUrls = suggestedUrlsFromVision.slice(0, 5); // Take top 5

    console.log("Successfully processed image. Identified:", identifiedName, "Suggestions:", finalSuggestedUrls.length);

    return new Response(
      JSON.stringify({
        suggestedUrls: finalSuggestedUrls,
        identifiedName: identifiedName,
        labels: labelsFromVision.slice(0, 5), // Return top 5 general labels
        webEntities: webEntities.slice(0,5), // Return top 5 web entities
      }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );

  } catch (error) {
    console.error("Error in Edge Function (could be auth or Vision API call):", error.message, error.stack);
    return new Response(JSON.stringify({ error: error.message || "Internal Server Error" }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
