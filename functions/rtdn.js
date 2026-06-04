/* eslint-disable max-len */
/**
 * LUGORENA — Google Play Real-Time Developer Notifications (RTDN) webhook.
 *
 * Google Play Console:
 *   - Monetization Setup → Real-time developer notifications → Pub/Sub topic
 *   - Pub/Sub topic → Push subscription → Cloud Functions endpoint.
 *
 * Push payload (base64 decoded) örneği:
 * {
 *   "version": "1.0",
 *   "packageName": "wardict.lugorena",
 *   "eventTimeMillis": "1730000000000",
 *   "subscriptionNotification": {
 *     "version": "1.0",
 *     "notificationType": 4, // 1=recovered, 2=renewed, 3=canceled,
 *                             // 4=purchased, 5=on_hold, 6=grace_period,
 *                             // 7=restarted, 12=revoked, 13=expired
 *     "purchaseToken": "...",
 *     "subscriptionId": "premium_monthly"
 *   }
 * }
 *
 * Apple eşdeğeri için ileride `appStoreServerNotifications` ayrı fonksiyon
 * eklenecek (App Store Server Notifications V2).
 */
const { onRequest } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { logger } = require("firebase-functions/v2");

const TYPES = {
  1: "recovered",
  2: "renewed",
  3: "canceled",
  4: "purchased",
  5: "on_hold",
  6: "grace_period",
  7: "restarted",
  12: "revoked",
  13: "expired",
};

exports.playRtdn = onRequest(
  { region: "us-central1", cors: false },
  async (req, res) => {
    try {
      if (!req.body || !req.body.message || !req.body.message.data) {
        logger.warn("RTDN: invalid payload", req.body);
        res.status(204).send();
        return;
      }
      const raw = Buffer.from(req.body.message.data, "base64").toString("utf-8");
      const payload = JSON.parse(raw);
      const db = getFirestore();

      const sub = payload.subscriptionNotification;
      if (sub) {
        const eventName = TYPES[sub.notificationType] || "unknown";
        const token = sub.purchaseToken;
        // purchaseToken <-> uid eşleşmesi: IAP doğrulamada kaydedilir
        const ledgerSnap = await db
          .collection("purchaseReceipts")
          .where("purchaseToken", "==", token)
          .limit(1)
          .get();

        let uid = null;
        if (!ledgerSnap.empty) {
          uid = ledgerSnap.docs[0].get("uid");
        }

        // RTDN event'ini merkezi koleksiyona yaz (audit log)
        await db.collection("rtdnEvents").add({
          type: "google_play",
          event: eventName,
          notificationType: sub.notificationType,
          subscriptionId: sub.subscriptionId,
          purchaseToken: token,
          uid,
          receivedAt: FieldValue.serverTimestamp(),
          raw: payload,
        });

        if (uid) {
          await _applySubscriptionEvent(db, uid, sub, eventName);
        }
      }

      res.status(204).send();
    } catch (e) {
      logger.error("RTDN processing error", e);
      // 5xx Google'a yeniden deneme sebebi olur — istersek 204 dönebiliriz.
      res.status(500).send({ ok: false, error: String(e) });
    }
  }
);

async function _applySubscriptionEvent(db, uid, sub, eventName) {
  const userRef = db.collection("users").doc(uid);
  const update = {
    lastSubscriptionEvent: eventName,
    lastSubscriptionEventAt: FieldValue.serverTimestamp(),
  };

  switch (eventName) {
    case "purchased":
    case "renewed":
    case "recovered":
    case "restarted":
      update.isPremium = true;
      // expiry ileride Play Developer API'den çekilecek (tahmini: +30 gün)
      update.premiumExpiresAt = Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      );
      break;
    case "grace_period":
      update.premiumGrace = true;
      break;
    case "on_hold":
      update.premiumOnHold = true;
      break;
    case "canceled":
      // User kaydı başlangıç; aktiflik sürene kadar isPremium true kalır.
      update.premiumCanceled = true;
      break;
    case "expired":
    case "revoked":
      update.isPremium = false;
      update.premiumExpiresAt = Timestamp.fromDate(new Date());
      break;
  }

  await userRef.set(update, { merge: true });
}
