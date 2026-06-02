require('dotenv').config();
const mongoose = require('mongoose');

const User = require('../models/User');
const Order = require('../models/Order');
const Inventory = require('../models/Inventory');

async function main() {
  await mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 30000,
    socketTimeoutMS: 45000,
  });

  const users = await User.find({ email: /^newuser_.*@test\.com$/i }).select('_id email');
  console.log(`test users found: ${users.length}`);
  if (!users.length) {
    await mongoose.disconnect();
    return;
  }

  const userIds = users.map((u) => u._id);
  const orders = await Order.find({ userId: { $in: userIds } }).lean();
  console.log(`orders found for test users: ${orders.length}`);

  // Roll back inventory for their orders
  const bulk = [];
  for (const o of orders) {
    for (const it of o.items || []) {
      if (it.productId && it.quantity) {
        bulk.push({
          updateOne: {
            filter: { productId: it.productId },
            update: { $inc: { quantity: it.quantity, sold: -it.quantity } },
          },
        });
      }
    }
  }
  if (bulk.length) {
    const res = await Inventory.bulkWrite(bulk);
    console.log(`inventory rollback ops: ${bulk.length}, matched: ${res.matchedCount}`);
  }

  const delOrders = await Order.deleteMany({ userId: { $in: userIds } });
  console.log(`deleted orders: ${delOrders.deletedCount}`);

  const delUsers = await User.deleteMany({ _id: { $in: userIds } });
  console.log(`deleted users: ${delUsers.deletedCount}`);

  await mongoose.disconnect();
}

main().catch((e) => {
  console.error('CLEANUP_ERR', e);
  process.exitCode = 1;
});

