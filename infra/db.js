/**
 * Placeholder storage layer. Swap this out for Postgres/MySQL/MongoDB
 * before going to production — a JSON file will not survive concurrent
 * writes or server restarts reliably.
 */

const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "subscriptions.json");

function readAll() {
  if (!fs.existsSync(FILE)) return {};
  return JSON.parse(fs.readFileSync(FILE, "utf-8") || "{}");
}

function writeAll(data) {
  fs.writeFileSync(FILE, JSON.stringify(data, null, 2));
}

async function savePendingTransaction({ tx_ref, userId, tier, status }) {
  const data = readAll();
  data[userId] = { ...(data[userId] || {}), tx_ref, tier, status };
  writeAll(data);
}

async function activateSubscription({ userId, tier, tx_ref }) {
  if (!userId) return;
  const data = readAll();
  const now = new Date();
  const renewsAt = new Date(now);
  renewsAt.setMonth(renewsAt.getMonth() + 1);

  data[userId] = {
    tier: tier || "normal",
    status: "active",
    tx_ref,
    activatedAt: now.toISOString(),
    renewsAt: renewsAt.toISOString(),
  };
  writeAll(data);
}

async function deactivateSubscription({ userId }) {
  if (!userId) return;
  const data = readAll();
  if (data[userId]) data[userId].status = "cancelled";
  writeAll(data);
}

async function getSubscriptionStatus(userId) {
  const data = readAll();
  return data[userId] || { tier: "none", status: "inactive" };
}

module.exports = {
  savePendingTransaction,
  activateSubscription,
  deactivateSubscription,
  getSubscriptionStatus,
};
