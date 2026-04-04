const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

async function getUserTokens(userId) {
  if (!userId) return [];

  const tokensSnap = await db
      .collection("users")
      .doc(userId)
      .collection("deviceTokens")
      .get();

  return tokensSnap.docs
      .map((doc) => {
        const data = doc.data() || {};
        return (data.token || "").toString();
      })
      .filter((token) => token.length > 0);
}

async function cleanupInvalidTokens(userId, tokens, response) {
  if (!userId || !tokens.length || !response) return;

  const invalidTokens = [];
  response.responses.forEach((r, index) => {
    if (!r.success) {
      const code = r.error?.code || "";
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(tokens[index]);
      }
    }
  });

  if (!invalidTokens.length) return;

  const batch = db.batch();
  invalidTokens.forEach((token) => {
    const ref = db
        .collection("users")
        .doc(userId)
        .collection("deviceTokens")
        .doc(token);
    batch.delete(ref);
  });
  await batch.commit();
}

async function sendUserPush({
  userId,
  title,
  body,
  data = {},
}) {
  if (!userId || !title || !body) return;

  const tokens = await getUserTokens(userId);
  if (!tokens.length) return;

  const multicastMessage = {
    tokens,
    notification: {
      title,
      body,
    },
    data: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value ?? "")]),
    ),
    android: {
      priority: "high",
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const response = await getMessaging().sendEachForMulticast(multicastMessage);
  await cleanupInvalidTokens(userId, tokens, response);
}

async function addUserNotification({
  userId,
  title,
  body,
  type,
  requestId = "",
  chatId = "",
  senderId = "",
  senderRole = "",
  extra = {},
}) {
  if (!userId || !title || !body || !type) return;

  await db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        title,
        body,
        type,
        requestId,
        chatId,
        senderId,
        senderRole,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
        ...extra,
      });
}

exports.sendChatMessagePush = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const message = snap.data();
      const chatId = event.params.chatId;

      const senderId = (message.senderId || "").toString();
      const text = (message.text || "").toString();
      const senderRole = (message.senderRole || "").toString();

      if (!senderId || !text) return;

      const chatRef = db.collection("chats").doc(chatId);
      const chatSnap = await chatRef.get();

      if (!chatSnap.exists) return;

      const chat = chatSnap.data() || {};
      const customerId = (chat.customerId || "").toString();
      const workerId = (chat.workerId || "").toString();
      const requestId = (chat.requestId || "").toString();

      const receiverId = senderId === customerId ? workerId : customerId;
      if (!receiverId) return;

      const title = senderRole === "worker" ?
        "رسالة جديدة من العامل" :
        "رسالة جديدة من العميل";

      const body = text.length > 100 ? `${text.substring(0, 100)}...` : text;

      await sendUserPush({
        userId: receiverId,
        title,
        body,
        data: {
          type: "chat_message",
          chatId,
          requestId,
          senderId,
          senderRole,
        },
      });

      await addUserNotification({
        userId: receiverId,
        title,
        body,
        type: "chat_message",
        requestId,
        chatId,
        senderId,
        senderRole,
      });
    },
);

exports.sendNewOfferNotification = onDocumentCreated(
    "requests/{requestId}/offers/{offerId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const offer = snap.data() || {};
      const requestId = (event.params.requestId || "").toString();
      if (!requestId) return;

      const requestRef = db.collection("requests").doc(requestId);
      const requestSnap = await requestRef.get();
      if (!requestSnap.exists) return;

      const request = requestSnap.data() || {};
      const customerId = (request.customerId || "").toString();
      const workerId = (offer.workerId || "").toString();
      const price = offer.price ?? "";
      const partName = (request.partName || "طلبك").toString();

      if (!customerId) return;

      const title = "عرض جديد على طلبك";
      const body = price ?
        `وصل عرض جديد على ${partName} بسعر ${price} ريال.` :
        `وصل عرض جديد على ${partName}.`;

      await sendUserPush({
        userId: customerId,
        title,
        body,
        data: {
          type: "new_offer",
          requestId,
          workerId,
          offerId: event.params.offerId || "",
        },
      });

      await addUserNotification({
        userId: customerId,
        title,
        body,
        type: "new_offer",
        requestId,
        senderId: workerId,
        senderRole: "worker",
        extra: {
          offerId: event.params.offerId || "",
          price: String(price ?? ""),
        },
      });

      await requestRef.set({
        newOffersCount: FieldValue.increment(1),
        lastOfferAt: FieldValue.serverTimestamp(),
        bestOfferPrice: typeof price === "number" ? price : Number(price) || 0,
      }, {merge: true});
    },
);

exports.sendRequestStatusNotifications = onDocumentUpdated(
    "requests/{requestId}",
    async (event) => {
      const before = event.data?.before?.data() || {};
      const after = event.data?.after?.data() || {};

      const requestId = (event.params.requestId || "").toString();
      const beforeStatus = (before.status || "").toString();
      const afterStatus = (after.status || "").toString();
      const beforeDriverId = (before.assignedDriverId || "").toString();
      const afterDriverId = (after.assignedDriverId || "").toString();
      const beforeDeliveryStatus = (before.deliveryStatus || "").toString();
      const afterDeliveryStatus = (after.deliveryStatus || "").toString();

      if (!requestId) return;

      const customerId = (after.customerId || "").toString();
      const workerId = (
        after.workerId ||
        after.assignedWorkerId ||
        after.acceptedWorkerId ||
        ""
      ).toString();

      const partName = (after.partName || "طلبك").toString();
      const acceptedPrice = after.acceptedOfferPrice ?? "";

      if (beforeDriverId !== afterDriverId && afterDriverId) {
        const driverTitle = "تم إسناد طلب جديد لك";
        const driverBody = `يوجد طلب جديد لقطعة ${partName} بانتظار الاستلام.`;

        await sendUserPush({
          userId: afterDriverId,
          title: driverTitle,
          body: driverBody,
          data: {
            type: "driver_assigned",
            requestId,
            driverId: afterDriverId,
            workerId,
            customerId,
          },
        });

        if (customerId) {
          const customerTitle = "تم تعيين سائق للطلب";
          const customerBody = `تم تعيين سائق لطلب ${partName} وسيبدأ الاستلام قريبًا.`;

          await sendUserPush({
            userId: customerId,
            title: customerTitle,
            body: customerBody,
            data: {
              type: "driver_assigned_customer",
              requestId,
              driverId: afterDriverId,
              workerId,
            },
          });
        }
      }

      if (beforeDeliveryStatus !== afterDeliveryStatus && customerId) {
        if (afterDeliveryStatus === "picked_up") {
          const title = "تم استلام الطلب";
          const body = `استلم السائق طلب ${partName} وجارٍ تجهيزه للتوصيل.`;

          await sendUserPush({
            userId: customerId,
            title,
            body,
            data: {
              type: "driver_picked_up",
              requestId,
              driverId: afterDriverId,
              workerId,
            },
          });
        }
      }

      if (beforeStatus === afterStatus) return;

      if (afterStatus === "assigned") {
        if (customerId) {
          const title = "تم قبول العرض";
          const body = acceptedPrice ?
            `تم اعتماد عرض ${partName} بسعر ${acceptedPrice} ريال.` :
            `تم اعتماد عرض على ${partName}.`;

          await sendUserPush({
            userId: customerId,
            title,
            body,
            data: {
              type: "offer_accepted",
              requestId,
              workerId,
            },
          });

          await addUserNotification({
            userId: customerId,
            title,
            body,
            type: "offer_accepted",
            requestId,
            senderId: workerId,
            senderRole: "worker",
            extra: {
              acceptedOfferPrice: String(acceptedPrice ?? ""),
            },
          });
        }

        if (workerId) {
          const title = "تم اختيار عرضك";
          const body = `تم اختيار عرضك على ${partName}.`;

          await sendUserPush({
            userId: workerId,
            title,
            body,
            data: {
              type: "offer_selected_for_worker",
              requestId,
              customerId,
            },
          });

          await addUserNotification({
            userId: workerId,
            title,
            body,
            type: "offer_selected_for_worker",
            requestId,
            senderId: customerId,
            senderRole: "customer",
          });
        }
      }

      if (afterStatus === "shipped" && customerId) {
        const title = "تم شحن الطلب";
        const body = `طلب ${partName} في الطريق إليك الآن.`;

        await sendUserPush({
          userId: customerId,
          title,
          body,
          data: {
            type: "request_shipped",
            requestId,
            workerId,
            driverId: afterDriverId,
          },
        });

        await addUserNotification({
          userId: customerId,
          title,
          body,
          type: "request_shipped",
          requestId,
          senderId: workerId || afterDriverId,
          senderRole: workerId ? "worker" : "driver",
        });
      }

      if (afterStatus === "delivered" && customerId) {
        const title = "تم تسليم الطلب";
        const body = `تم تسليم ${partName} بنجاح.`;

        await sendUserPush({
          userId: customerId,
          title,
          body,
          data: {
            type: "request_delivered",
            requestId,
            workerId,
            driverId: afterDriverId,
          },
        });

        await addUserNotification({
          userId: customerId,
          title,
          body,
          type: "request_delivered",
          requestId,
          senderId: workerId || afterDriverId,
          senderRole: workerId ? "worker" : "driver",
        });
      }
    },
);
