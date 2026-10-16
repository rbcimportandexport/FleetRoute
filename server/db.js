// server/db.js
// Persistent Database Layer with Real MongoDB Persistence
// STRICTLY ZERO EMOJIS. NO IN-MEMORY DEMO FALLBACK.

const mongoose = require('mongoose');
const models = require('./models');

class DataStore {
  constructor() {
    this.models = {
      users: models.User,
      drivers: models.Driver,
      vehicles: models.Vehicle,
      products: models.Product,
      locations: models.Location,
      trips: models.Trip,
      safetyEvents: models.SafetyEvent,
      deliveryProofs: models.DeliveryProof,
      locationSamples: models.LocationSample,
      settings: models.SystemSetting,
      emergencyIncidents: models.EmergencyIncident,
      emergencyDeliveryAttempts: models.EmergencyDeliveryAttempt,
      emergencyContacts: models.EmergencyContact,
      hospitals: models.Hospital,
      ambulanceUnits: models.AmbulanceUnit,
      safetyServiceHealth: models.SafetyServiceHealth
    };
  }

  async connect(uri = process.env.MONGODB_URI || process.env.MONGO_URI || (process.env.NODE_ENV === 'production' ? null : 'mongodb://127.0.0.1:27017/fleetroute')) {
    if (!uri) {
      throw new Error('MONGODB_URI is required in production.');
    }

    const redactedUri = uri.replace(/(mongodb(?:\+srv)?:\/\/)([^@/]+)@/i, '$1[credentials-redacted]@');
    try {
      await mongoose.connect(uri, { 
        serverSelectionTimeoutMS: 5000,
        autoIndex: true
      });
      console.log(`[FleetRoute Database] Connected to persistent MongoDB at ${redactedUri}`);
    } catch (err) {
      console.error(`[FleetRoute Database CRITICAL] Failed to connect to MongoDB at ${redactedUri}:`, err.message);
      // Strictly fail startup when database connection cannot be established
      throw new Error(`Production Database Unavailable: MongoDB connection failed (${err.message})`);
    }
  }

  async disconnect() {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
  }

  isConnected() {
    return mongoose.connection.readyState === 1;
  }

  health() {
    const isOnline = this.isConnected();
    return {
      status: isOnline ? 'ONLINE_PERSISTENT' : 'OFFLINE_DISCONNECTED',
      storageType: 'mongodb',
      isDemoMode: false,
      readyState: mongoose.connection.readyState,
      database: mongoose.connection.name || 'fleetroute'
    };
  }

  collection(name) {
    const Model = this.models[name];
    if (!Model) {
      throw new Error(`Unknown database collection: ${name}`);
    }

    return {
      find: async (filter = {}) => {
        const query = filter ? { ...filter } : {};
        return await Model.find(query).lean().exec();
      },

      findOne: async (filter = {}) => {
        const query = filter ? { ...filter } : {};
        return await Model.findOne(query).lean().exec();
      },

      findById: async (id) => {
        if (!id) return null;
        const query = mongoose.Types.ObjectId.isValid(id)
          ? { $or: [{ id: String(id) }, { _id: id }] }
          : { id: String(id) };
        return await Model.findOne(query).lean().exec();
      },

      insertOne: async (doc) => {
        const idPrefix = name.toUpperCase().slice(0, 3);
        const toInsert = {
          ...doc,
          id: doc.id || `${idPrefix}-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`
        };
        const created = await Model.create(toInsert);
        return created.toObject ? created.toObject() : created;
      },

      insertMany: async (docs) => {
        const idPrefix = name.toUpperCase().slice(0, 3);
        const prepared = docs.map((doc, idx) => ({
          ...doc,
          id: doc.id || `${idPrefix}-${Date.now()}-${idx}`
        }));
        const created = await Model.insertMany(prepared);
        return created.map(d => d.toObject ? d.toObject() : d);
      },

      updateOne: async (filter, update) => {
        const query = filter ? { ...filter } : {};
        let finalUpdate = {};

        // If mongo update operators ($set, $push, etc.) are already used, pass them through
        const hasOperators = Object.keys(update).some(k => k.startsWith('$'));
        if (hasOperators) {
          finalUpdate = { ...update };
          if (!finalUpdate.$set) finalUpdate.$set = {};
          finalUpdate.$set.updatedAt = new Date();
        } else {
          finalUpdate = {
            $set: { ...update, updatedAt: new Date() }
          };
        }

        const updated = await Model.findOneAndUpdate(
          query,
          finalUpdate,
          { new: true, runValidators: false }
        ).lean().exec();
        return updated;
      },

      deleteOne: async (filter) => {
        const query = filter ? { ...filter } : {};
        const deleted = await Model.findOneAndDelete(query).lean().exec();
        return deleted;
      },

      count: async (filter = {}) => {
        const query = filter ? { ...filter } : {};
        return await Model.countDocuments(query).exec();
      },

      clear: async () => {
        return await Model.deleteMany({}).exec();
      }
    };
  }
}

const db = new DataStore();
module.exports = db;
