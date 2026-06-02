require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: node scripts/set_admin_role.js <email>');
    process.exitCode = 1;
    return;
  }

  await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 15000 });

  const before = await User.findOne({ email }).select('email role name');
  console.log('before', before ? { email: before.email, role: before.role, name: before.name } : null);

  const res = await User.updateOne({ email }, { $set: { role: 'admin' } });
  console.log('updated', { matched: res.matchedCount, modified: res.modifiedCount });

  const after = await User.findOne({ email }).select('email role name');
  console.log('after', after ? { email: after.email, role: after.role, name: after.name } : null);

  await mongoose.disconnect();
}

main().catch((e) => {
  console.error('ERR', e.message);
  process.exitCode = 1;
});

