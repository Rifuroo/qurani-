// lib/models/premium_features.dart
// Premium feature definitions and gating logic

enum PremiumFeature {
  // Memorization
  mistakeDetection,
  tashkeelMistakes,
  tajweedMistakes,
  tajweedColors, // Show tajweed colors in text
  versePeeking,
  mistakeHistory,
  mistakeFrequency,
  mistakePlayback,

  // Recitation
  unlimitedSessionAudio,
  unlimitedShareAudio,
  sessionPausing,

  // Progress
  unlimitedSessionHistory,
  advancedAnalytics,
  mistakesOverview,
  addExternalSessions,

  // Challenges
  unlimitedGoals,
  discoverBadges,
  notifications,

  // Audio
  wordByWordAudio,

  // Search
  extendedSearchHistory,
}

/// Features that are ONLY available for Premium users
const Set<PremiumFeature> premiumOnlyFeatures = {
  // Memorization
  PremiumFeature.mistakeDetection,
  PremiumFeature.tashkeelMistakes,
  PremiumFeature.tajweedMistakes,
  PremiumFeature.tajweedColors,
  PremiumFeature.versePeeking,
  PremiumFeature.mistakeHistory,
  PremiumFeature.mistakeFrequency,
  PremiumFeature.mistakePlayback,

  // Recitation
  PremiumFeature.unlimitedSessionAudio,
  PremiumFeature.unlimitedShareAudio,
  PremiumFeature.sessionPausing,

  // Progress
  PremiumFeature.unlimitedSessionHistory,
  PremiumFeature.advancedAnalytics,
  PremiumFeature.mistakesOverview,
  PremiumFeature.addExternalSessions,

  // Challenges
  PremiumFeature.unlimitedGoals,
  PremiumFeature.discoverBadges,
  PremiumFeature.notifications,

  // Audio
  PremiumFeature.wordByWordAudio,

  // Search
  PremiumFeature.extendedSearchHistory,
};

/// Get human-readable name for a feature
String getFeatureName(PremiumFeature feature) {
  switch (feature) {
    case PremiumFeature.mistakeDetection:
      return 'Mistake Detection';
    case PremiumFeature.tashkeelMistakes:
      return 'Tashkeel Mistakes';
    case PremiumFeature.tajweedMistakes:
      return 'Tajweed Mistakes';
    case PremiumFeature.tajweedColors:
      return 'Tajweed Colors';
    case PremiumFeature.versePeeking:
      return 'Verse Peeking';
    case PremiumFeature.mistakeHistory:
      return 'Mistake History';
    case PremiumFeature.mistakeFrequency:
      return 'Mistake Frequency';
    case PremiumFeature.mistakePlayback:
      return 'Mistake Playback';
    case PremiumFeature.unlimitedSessionAudio:
      return 'Unlimited Session Audio';
    case PremiumFeature.unlimitedShareAudio:
      return 'Unlimited Share Audio';
    case PremiumFeature.sessionPausing:
      return 'Session Pausing';
    case PremiumFeature.unlimitedSessionHistory:
      return 'Unlimited Session History';
    case PremiumFeature.advancedAnalytics:
      return 'Advanced Analytics';
    case PremiumFeature.mistakesOverview:
      return 'Mistakes Overview';
    case PremiumFeature.addExternalSessions:
      return 'Add External Sessions';
    case PremiumFeature.unlimitedGoals:
      return 'Unlimited Goals';
    case PremiumFeature.discoverBadges:
      return 'Discover Badges';
    case PremiumFeature.notifications:
      return 'Notifications';
    case PremiumFeature.wordByWordAudio:
      return 'Word by Word Audio';
    case PremiumFeature.extendedSearchHistory:
      return 'Extended Search History';
  }
}

/// Get description for a feature
String getFeatureDescription(PremiumFeature feature) {
  switch (feature) {
    case PremiumFeature.mistakeDetection:
      return 'Get instant feedback on recitation mistakes';
    case PremiumFeature.tashkeelMistakes:
      return 'Detect tashkeel/diacritics errors';
    case PremiumFeature.tajweedMistakes:
      return 'Identify tajweed rule violations';
    case PremiumFeature.tajweedColors:
      return 'Color letters according to tajweed rules';
    case PremiumFeature.versePeeking:
      return 'Peek at upcoming verses while reciting';
    case PremiumFeature.mistakeHistory:
      return 'View your past mistakes for review';
    case PremiumFeature.mistakeFrequency:
      return 'See which mistakes you make most often';
    case PremiumFeature.mistakePlayback:
      return 'Listen to your mistakes with corrections';
    case PremiumFeature.unlimitedSessionAudio:
      return 'Access all your session recordings';
    case PremiumFeature.unlimitedShareAudio:
      return 'Share unlimited audio recordings';
    case PremiumFeature.sessionPausing:
      return 'Pause and resume your sessions';
    case PremiumFeature.unlimitedSessionHistory:
      return 'Access your complete session history';
    case PremiumFeature.advancedAnalytics:
      return 'Detailed insights into your progress';
    case PremiumFeature.mistakesOverview:
      return 'Comprehensive view of all mistakes';
    case PremiumFeature.addExternalSessions:
      return 'Log sessions from other sources';
    case PremiumFeature.unlimitedGoals:
      return 'Set unlimited memorization goals';
    case PremiumFeature.discoverBadges:
      return 'Discover and preview all badges';
    case PremiumFeature.notifications:
      return 'Get reminders and notifications';
    case PremiumFeature.wordByWordAudio:
      return 'Follow along word by word';
    case PremiumFeature.extendedSearchHistory:
      return 'Keep more search history (15 vs 3)';
  }
}



