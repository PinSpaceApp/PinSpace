// lib/models/achievement.dart
import 'package:flutter/material.dart';

// Enum to categorize achievements (optional, but can be useful for filtering/display)
enum AchievementCategory { collection, trading, social, sets }

class Achievement {
  final String id; // Unique identifier (e.g., "collect_10_pins")
  final String name;
  final String description;
  final IconData iconData; // Using Material Icons for now
  final Color iconColor; // Color for the unlocked badge icon
  final Color backgroundColor; // Background for the unlocked badge
  final int criteriaValue; // e.g., 10 for "collect 10 pins"
  final int pointsAwarded;
  final AchievementCategory category;
  final String? tierName; // e.g., "Bronze", "Tier 1"

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconData,
    required this.iconColor,
    required this.backgroundColor,
    required this.criteriaValue,
    this.pointsAwarded = 10, // Default points
    required this.category,
    this.tierName,
  });
}

class UserAchievement {
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;

  UserAchievement({
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
  });

  factory UserAchievement.fromMap(Map<String, dynamic> map) {
    return UserAchievement(
      // Assuming 'user_id' and 'achievement_id' are column names in your Supabase table
      userId: map['user_id'] as String, 
      achievementId: map['achievement_id'] as String,
      unlockedAt: DateTime.parse(map['unlocked_at'] as String),
    );
  }
}

// Master List of All Available Achievements
// You'll expand this list based on the "PinSpace Trophy & Badge Ideas"
final List<Achievement> allAchievements = [
  // --- Collection Milestones ---
  const Achievement(
    id: "collect_first_pin", name: "First Pin Acquired!", description: "Add your very first pin to your collection.",
    iconData: Icons.star_outline, iconColor: Colors.amber, backgroundColor: Colors.amberAccent,
    criteriaValue: 1, pointsAwarded: 10, category: AchievementCategory.collection,
  ),
  const Achievement(
    id: "collect_5_pins", name: "Pin Novice", description: "Own 5 pins.",
    iconData: Icons.filter_5, iconColor: Colors.white, backgroundColor: Colors.brown.shade300,
    criteriaValue: 5, pointsAwarded: 10, category: AchievementCategory.collection, tierName: "Tier 1",
  ),
  const Achievement(
    id: "collect_10_pins", name: "Pin Apprentice", description: "Own 10 pins.",
    iconData: Icons.filter_9_plus, iconColor: Colors.white, backgroundColor: Colors.brown.shade400,
    criteriaValue: 10, pointsAwarded: 15, category: AchievementCategory.collection, tierName: "Tier 2",
  ),
  const Achievement(
    id: "collect_20_pins", name: "Pin Collector", description: "Own 20 pins.",
    iconData: Icons.collections_bookmark_outlined, iconColor: Colors.white, backgroundColor: Colors.blueGrey.shade400,
    criteriaValue: 20, pointsAwarded: 20, category: AchievementCategory.collection, tierName: "Tier 3",
  ),
   const Achievement(
    id: "collect_40_pins", name: "Pin Enthusiast", description: "Own 40 pins.",
    iconData: Icons.auto_awesome_mosaic_outlined, iconColor: Colors.white, backgroundColor: Colors.blueGrey.shade600,
    criteriaValue: 40, pointsAwarded: 25, category: AchievementCategory.collection, tierName: "Tier 4",
  ),
  const Achievement(
    id: "collect_100_pins", name: "Pin Veteran", description: "Own 100 pins.",
    iconData: Icons.military_tech_outlined, iconColor: Colors.yellowAccent, backgroundColor: Colors.grey.shade700,
    criteriaValue: 100, pointsAwarded: 50, category: AchievementCategory.collection, tierName: "Tier 7",
  ),

  // --- Set Milestones ---
  const Achievement(
    id: "set_starter", name: "Set Starter", description: "Create your first pin set.",
    iconData: Icons.create_new_folder_outlined, iconColor: Colors.teal, backgroundColor: Colors.tealAccent.shade100,
    criteriaValue: 1, pointsAwarded: 15, category: AchievementCategory.sets,
  ),
  const Achievement(
    id: "set_completer_1", name: "Set Completer!", description: "Complete your first pin set.",
    iconData: Icons.check_circle_outline, iconColor: Colors.green, backgroundColor: Colors.greenAccent.shade100,
    criteriaValue: 1, pointsAwarded: 25, category: AchievementCategory.sets, tierName: "Tier 1",
  ),
   const Achievement(
    id: "set_completer_5", name: "Dedicated Set Builder", description: "Complete 5 pin sets.",
    iconData: Icons.library_add_check_outlined, iconColor: Colors.lightGreen, backgroundColor: Colors.lightGreen.shade100,
    criteriaValue: 5, pointsAwarded: 50, category: AchievementCategory.sets, tierName: "Tier 2",
  ),

  // --- Trading Milestones ---
  const Achievement(
    id: "trade_offer_sent", name: "Making Moves", description: "Send your first trade offer.",
    iconData: Icons.send_outlined, iconColor: Colors.purple, backgroundColor: Colors.purpleAccent.shade100,
    criteriaValue: 1, pointsAwarded: 5, category: AchievementCategory.trading,
  ),
  const Achievement(
    id: "trade_accepted_1", name: "Successful Swap!", description: "Complete your first successful trade.",
    iconData: Icons.handshake_outlined, iconColor: Colors.orange, backgroundColor: Colors.orangeAccent.shade100,
    criteriaValue: 1, pointsAwarded: 20, category: AchievementCategory.trading,
  ),
  const Achievement(
    id: "fair_trader_5", name: "Fair Trader", description: "Complete 5 successful trades.",
    iconData: Icons.swap_horiz_outlined, iconColor: Colors.deepOrange, backgroundColor: Colors.deepOrangeAccent.shade100,
    criteriaValue: 5, pointsAwarded: 30, category: AchievementCategory.trading, tierName: "Tier 1",
  ),
  const Achievement(
    id: "market_mover_1", name: "Market Mover", description: "List your first pin 'For Trade'.",
    iconData: Icons.storefront_outlined, iconColor: Colors.cyan, backgroundColor: Colors.cyanAccent.shade100,
    criteriaValue: 1, pointsAwarded: 10, category: AchievementCategory.trading,
  ),

  // --- Social Milestones ---
  const Achievement(
    id: "profile_complete", name: "Welcome to the Club!", description: "Complete your profile (avatar & bio).",
    iconData: Icons.account_circle_outlined, iconColor: Colors.indigo, backgroundColor: Colors.indigoAccent.shade100,
    criteriaValue: 1, pointsAwarded: 10, category: AchievementCategory.social,
  ),
  const Achievement(
    id: "first_follow", name: "Friendly Follower", description: "Follow another user.",
    iconData: Icons.person_add_alt_1_outlined, iconColor: Colors.lightBlue, backgroundColor: Colors.lightBlueAccent.shade100,
    criteriaValue: 1, pointsAwarded: 5, category: AchievementCategory.social,
  ),
  const Achievement(
    id: "making_friends_5", name: "Social Butterfly", description: "Follow 5 users.",
    iconData: Icons.group_add_outlined, iconColor: Colors.blue, backgroundColor: Colors.blueAccent.shade100,
    criteriaValue: 5, pointsAwarded: 10, category: AchievementCategory.social, tierName: "Tier 1",
  ),
  const Achievement(
    id: "first_follower", name: "Gaining Traction", description: "Get your first follower.",
    iconData: Icons.person_search_outlined, iconColor: Colors.pink, backgroundColor: Colors.pinkAccent.shade100,
    criteriaValue: 1, pointsAwarded: 10, category: AchievementCategory.social,
  ),
  const Achievement(
    id: "first_post", name: "Community Voice", description: "Make your first activity post.",
    iconData: Icons.campaign_outlined, iconColor: Colors.lime, backgroundColor: Colors.limeAccent.shade100,
    criteriaValue: 1, pointsAwarded: 5, category: AchievementCategory.social,
  ),
  // Add more achievements based on your list...
];
