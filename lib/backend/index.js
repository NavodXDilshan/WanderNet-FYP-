const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const uri = process.env.MONGODB_URI;

app.use(cors());
app.use(express.json());

let client = new MongoClient(uri);

async function connectToMongoDB() {
  try {
    await client.connect();
    console.log('Connected to MongoDB');
    
    // Add connection monitoring
    client.on('close', () => {
      console.log('MongoDB connection closed. Attempting to reconnect...');
      setTimeout(reconnect, 5000); // Try to reconnect after 5 seconds
    });

    client.on('error', (error) => {
      console.error('MongoDB connection error:', error);
      setTimeout(reconnect, 5000);
    });

  } catch (error) {
    console.error('MongoDB connection error:', error);
    setTimeout(reconnect, 5000);
  }
}

async function reconnect() {
  try {
    if (client) {
      await client.close(); // Close existing connection
    }
    client = new MongoClient(uri); // Create new client
    await connectToMongoDB();
  } catch (error) {
    console.error('Reconnection failed:', error);
    setTimeout(reconnect, 5000);
  }
}

// Helper function to get database connection
async function getDatabase() {
  if (!client.topology || !client.topology.isConnected()) {
    await reconnect();
  }
  return client.db('posts_db');
}

// Modify your existing routes to use getDatabase()
app.get('/posts', async (req, res) => {
  try {
    const database = await getDatabase();
    const posts = database.collection('posts');
    const postList = await posts
      .find({})
      .sort({ createdAt: -1 })
      .limit(20)
      .toArray();
    res.json(postList);
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ error: 'Failed to fetch posts' });
  }
});

// Add at the bottom of index.js
process.on('SIGINT', async () => {
  try {
    await client.close();
    console.log('MongoDB connection closed through app termination');
    process.exit(0);
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
});