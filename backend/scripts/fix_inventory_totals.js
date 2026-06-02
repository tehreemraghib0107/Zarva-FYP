require('dotenv').config();
const mongoose = require('mongoose');

const Inventory = require('../models/Inventory');

async function main() {
  await mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 30000,
    socketTimeoutMS: 45000,
  });

  // Historical fix:
  // Old behavior decremented `quantity` and incremented `sold`.
  // That means current `quantity` often equals "remaining", and true total should be quantity + sold.
  const inventories = await Inventory.find({});
  let updated = 0;

  for (const inv of inventories) {
    const q = Number(inv.quantity || 0);
    const s = Number(inv.sold || 0);
    if (s > 0) {
      const restoredTotal = q + s;
      if (restoredTotal !== q) {
        inv.quantity = restoredTotal;
        await inv.save();
        updated++;
      }
    }
  }

  console.log(`Inventory totals restored for ${updated} records.`);
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error('FIX_INVENTORY_TOTALS_ERR', e);
  process.exitCode = 1;
});

