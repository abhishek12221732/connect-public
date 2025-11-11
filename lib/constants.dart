// lib/constants.dart

// IMPORTANT: Replace 'YOUR_CANVAS_APP_ID_HERE' with your actual Canvas App ID.
// You can find this in the URL of your Canvas project:
// e.g., https://canvas.google.com/apps/{YOUR_APP_ID}/edit
// Or in your Firebase project settings under 'Your apps' -> 'Web app' section.
const String kAppId = 'YOUR_CANVAS_APP_ID_HERE';

// Define the categories and subcategories with better names
const Map<String, dynamic> kCategoriesData = {
  "Foundation": {
    "subCategories": ["Rooted Memories", "Self-Discovery"],
    "description": "Delve into individual pasts and personal growth journeys."
  },
  "Aspirations": {
    "subCategories": ["Future Horizons", "Guiding Principles"],
    "description": "Explore dreams, values, and what drives personal ambition."
  },
  "Emotional Landscape": {
    "subCategories": ["Inner Depths", "Expressions of Affection"],
    "description": "Understand feelings, vulnerabilities, and how love is given and received."
  },
  "Our Connection": {
    "subCategories": ["Connecting Voices", "Our Shared Journey"],
    "description": "Examine communication styles and envision the future of the relationship."
  },
  "Lighthearted & Quirky": {
    "subCategories": ["Everyday Delights", "What If Scenarios"],
    "description": "Discover fun preferences, habits, and playful hypothetical situations."
  },
  "Relationship Reflections": {
    "subCategories": ["Shared Milestones", "Evolving Together"],
    "description": "Look back on the relationship's path and anticipate future growth."
  }
};
