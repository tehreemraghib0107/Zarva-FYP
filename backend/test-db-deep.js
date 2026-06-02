const mongoose = require('mongoose');
require('dotenv').config();

console.log("Current MONGO_URI from .env:", process.env.MONGO_URI ? "Exists (hidden)" : "MISSING");

async function check() {
    console.log("\n--- Connectivity Diagnostic ---");

    // 1. Check DNS resolution for SRV
    const dns = require('dns');
    dns.resolveSrv('_mongodb._tcp.cluster0.hicahnr.mongodb.net', (err, addresses) => {
        if (err) {
            console.error("DNS SRV Resolution FAILED:", err.code);
            console.log("👉 Suggestion: Your current network/DNS cannot find the Atlas SRV records.");
        } else {
            console.log("DNS SRV Resolution: SUCCESS", addresses.length, "shards found.");
        }
    });

    // 2. Check direct shard connectivity
    const shards = [
        'cluster0-shard-00-00.hicahnr.mongodb.net',
        'cluster0-shard-00-01.hicahnr.mongodb.net',
        'cluster0-shard-00-02.hicahnr.mongodb.net'
    ];

    for (const shard of shards) {
        dns.lookup(shard, (err, address) => {
            if (err) {
                console.error(`DNS Lookup FAILED for ${shard}:`, err.code);
            } else {
                console.log(`DNS Lookup SUCCESS for ${shard} -> ${address}`);
            }
        });
    }

    // 3. Attempt mongoose connection with more detail
    try {
        console.log("\nAttempting Mongoose connection (15s timeout)...");
        await mongoose.connect(process.env.MONGO_URI, {
            serverSelectionTimeoutMS: 15000,
        });
        console.log("✅ ZARVA Database Connected Successfully!");
        process.exit(0);
    } catch (err) {
        console.error("❌ Mongoose Connection Error:", err.name);
        console.error("Error Message:", err.message);
        if (err.reason) {
            console.error("Failure Reason:", JSON.stringify(err.reason, null, 2));
        }
        process.exit(1);
    }
}

check();
