/**
 * Minimal subscription payment backend using Flutterwave.
 *
 * Flow:
 *  1. App calls POST /api/subscribe  -> gets back a checkout link
 *  2. User pays via mobile money or card on that link
 *  3. Flutterwave redirects user to REDIRECT_URL (frontend can call /api/verify)
 *  4. Flutterwave ALSO calls POST /api/webhook server-to-server (source of truth)
 *
 * Storage here is a simple JSON file for demo purposes only.
 * Replace `db.js` with a real database (Postgres/Mongo/etc.) before production.
 */

require("dotenv").config();
const express = require("express");
const axios = require("axios");
const crypto = require("crypto");
const db = require("./db");

const app = express();
app.use(express.json());

const FLW_BASE = "https://api.flutterwave.com/v3";
const FLW_SECRET_KEY = process.env.FLW_SECRET_KEY;

const PLANS = {
  normal: process.env.PLAN_ID_NORMAL,
  premium: process.env.PLAN_ID_PREMIUM,
};

/**
 * POST /api/subscribe
 * body: { userId, email, phone, name, tier: "normal" | "premium" }
 * returns: { checkoutUrl }
 */
app.post("/api/subscribe", async (req, res) => {
  try {
    const { userId, email, phone, name, tier } = req.body;

    if (!userId || !email || !tier || !PLANS[tier]) {
      return res.status(400).json({ error: "Missing userId, email, or valid tier" });
    }

    const tx_ref = `sub_${userId}_${Date.now()}`;

    const response = await axios.post(
      `${FLW_BASE}/payments`,
      {
        tx_ref,
        amount: tier === "premium" ? "5000" : "2000", // XAF, adjust to your pricing
        currency: "XAF",
        payment_plan: PLANS[tier],
        redirect_url: process.env.REDIRECT_URL,
        customer: { email, phonenumber: phone, name },
        payment_options: "mobilemoneycameroon,card",
        meta: { userId, tier },
      },
      { headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` } }
    );

    // Track the pending transaction locally so we can reconcile later
    await db.savePendingTransaction({ tx_ref, userId, tier, status: "pending" });

    res.json({ checkoutUrl: response.data.data.link, tx_ref });
  } catch (err) {
    console.error("subscribe error:", err.response?.data || err.message);
    res.status(500).json({ error: "Could not initiate payment" });
  }
});

/**
 * GET /api/verify?tx_ref=xxx  OR  ?transaction_id=xxx
 * Called by your app/frontend right after redirect, for immediate UI feedback.
 * The webhook below remains the authoritative source of truth.
 */
app.get("/api/verify", async (req, res) => {
  try {
    const { transaction_id } = req.query;
    if (!transaction_id) return res.status(400).json({ error: "transaction_id required" });

    const response = await axios.get(`${FLW_BASE}/transactions/${transaction_id}/verify`, {
      headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` },
    });

    const data = response.data.data;
    const success = data.status === "successful";

    if (success) {
      await db.activateSubscription({
        userId: data.meta?.userId,
        tier: data.meta?.tier,
        tx_ref: data.tx_ref,
      });
    }

    res.json({ success, status: data.status });
  } catch (err) {
    console.error("verify error:", err.response?.data || err.message);
    res.status(500).json({ error: "Verification failed" });
  }
});

/**
 * POST /api/webhook
 * Flutterwave calls this server-to-server. This is the source of truth
 * for unlocking/renewing subscriptions — never trust the redirect alone.
 */
app.post("/api/webhook", async (req, res) => {
  const signature = req.headers["verif-hash"];

  if (!signature || signature !== process.env.FLW_WEBHOOK_SECRET) {
    return res.status(401).send("Invalid signature");
  }

  const event = req.body;

  try {
    if (event.event === "charge.completed" && event.data.status === "successful") {
      const { userId, tier } = event.data.meta || {};
      await db.activateSubscription({ userId, tier, tx_ref: event.data.tx_ref });
      console.log(`Activated ${tier} subscription for user ${userId}`);
    }

    if (event.event === "subscription.cancelled") {
      const { userId } = event.data.meta || {};
      await db.deactivateSubscription({ userId });
      console.log(`Deactivated subscription for user ${userId}`);
    }

    // Always 200 quickly so Flutterwave doesn't retry unnecessarily
    res.sendStatus(200);
  } catch (err) {
    console.error("webhook processing error:", err);
    res.sendStatus(200); // still ack receipt; log and fix internally
  }
});

/**
 * GET /api/status/:userId
 * Your app polls this (or checks on launch) to know if the user is premium/normal.
 */
app.get("/api/status/:userId", async (req, res) => {
  const status = await db.getSubscriptionStatus(req.params.userId);
  res.json(status);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Payment backend running on port ${PORT}`));
