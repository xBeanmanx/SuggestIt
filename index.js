// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Scheduled function to delete accepted suggestions older than 7 days
exports.deleteOldAcceptedSuggestions = functions.pubsub
  .schedule('every 24 hours') // Runs daily
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const db = admin.firestore();
    
    try {
      // Calculate date 7 days ago
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      
      // Query for accepted suggestions older than 7 days
      const oldSuggestions = await db
        .collection('suggestions')
        .where('status', '==', 'accepted')
        .where('acceptedAt', '<', admin.firestore.Timestamp.fromDate(weekAgo))
        .get();
      
      console.log(`Found ${oldSuggestions.size} suggestions to delete`);
      
      // Delete in batches
      const batchSize = 500;
      const batches = [];
      let currentBatch = db.batch();
      let operationCount = 0;
      
      oldSuggestions.docs.forEach((doc, index) => {
        currentBatch.delete(doc.ref);
        operationCount++;
        
        if (operationCount === batchSize) {
          batches.push(currentBatch.commit());
          currentBatch = db.batch();
          operationCount = 0;
        }
      });
      
      // Commit remaining operations
      if (operationCount > 0) {
        batches.push(currentBatch.commit());
      }
      
      // Wait for all batches to complete
      await Promise.all(batches);
      
      console.log(`Successfully deleted ${oldSuggestions.size} old accepted suggestions`);
      return null;
    } catch (error) {
      console.error('Error deleting old suggestions:', error);
      throw error;
    }
  });