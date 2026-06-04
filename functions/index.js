/* eslint-disable max-len */
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// ------- Ekonomi ve IAP doğrulama callable'ları -------
const economy = require("./economy");
const iap = require("./iap");

exports.secureAddCoins = economy.secureAddCoins;
exports.secureSpendCoins = economy.secureSpendCoins;
exports.claimDailyBonus = economy.claimDailyBonus;
exports.claimQuestReward = economy.claimQuestReward;
exports.redeemPromoCode = economy.redeemPromoCode;
exports.redeemReferral = economy.redeemReferral;
exports.verifyPurchase = iap.verifyPurchase;
// ------------------------------------------------------

/**
 * Duel daveti oluşturulduğunda hedef kullanıcıya bildirim gönderir.
 * Firestore path: duelInvitations/{invitationId}
 */
exports.onDuelInvitationCreated = onDocumentCreated(
  "duelInvitations/{invitationId}",
  async (event) => {
    const invitation = event.data.data();

    if (!invitation) return;

    const toUserId = invitation.toUserId;
    const fromUsername = invitation.fromUsername || invitation.fromUser?.username || "Bir oyuncu";
    const leagueCode = invitation.leagueCode || "";

    if (!toUserId) {
      console.log("❌ toUserId bulunamadı, bildirim gönderilemiyor.");
      return;
    }

    // Hedef kullanıcının FCM token'ını al
    const db = getFirestore();
    const userDoc = await db.collection("users").doc(toUserId).get();

    if (!userDoc.exists) {
      console.log(`❌ Kullanıcı bulunamadı: ${toUserId}`);
      return;
    }

    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`⚠️ FCM token yok: ${toUserId} - Bildirim gönderilemedi.`);
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: "⚔️ Düello Daveti!",
        body: `${fromUsername} seni bir düelloya davet etti! ${leagueCode ? `(${leagueCode} Ligi)` : ""}`,
      },
      data: {
        type: "duel_invitation",
        invitationId: event.params.invitationId,
        fromUsername: fromUsername,
        leagueCode: leagueCode,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "duel_invitations",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await getMessaging().send(message);
      console.log(`✅ Bildirim gönderildi: ${response}`);

      // Davet belgesini güncelle (bildirim gönderildi olarak işaretle)
      await event.data.ref.update({
        notificationSent: true,
        notificationSentAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("❌ Bildirim gönderilemedi:", error);

      // Token geçersizse temizle
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(toUserId).update({
          fcmToken: FieldValue.delete(),
        });
        console.log(`🗑️ Geçersiz token silindi: ${toUserId}`);
      }
    }
  }
);

/**
 * Duel daveti kabul edildiğinde davet eden kullanıcıya bildirim gönderir.
 */
exports.onDuelInvitationAccepted = onDocumentUpdated(
  "duelInvitations/{invitationId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Sadece status "pending" -> "accepted" geçişini yakala
    if (before.status !== "pending" || after.status !== "accepted") {
      return;
    }

    const fromUserId = after.fromUserId;
    const toUsername = after.toUsername || after.toUser?.username || "Rakibin";

    if (!fromUserId) return;

    const db = getFirestore();
    const userDoc = await db.collection("users").doc(fromUserId).get();

    if (!userDoc.exists) return;

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const message = {
      token: fcmToken,
      notification: {
        title: "✅ Davet Kabul Edildi!",
        body: `${toUsername} düello davetini kabul etti! Oyun başlıyor...`,
      },
      data: {
        type: "duel_accepted",
        matchId: after.matchId || "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "duel_invitations",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`✅ Kabul bildirimi gönderildi: ${fromUserId}`);
    } catch (error) {
      console.error("❌ Kabul bildirimi gönderilemedi:", error);
    }
  }
);
