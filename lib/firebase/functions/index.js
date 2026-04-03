const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

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

    const tokensSnap = await db
      .collection("users")
      .doc(receiverId)
      .collection("deviceTokens")
      .get();

    const tokens = tokensSnap.docs
      .map((doc) => {
        const data = doc.data() || {};
        return (data.token || "").toString();
      })
      .where((token) => token.length > 0);

    if (tokens.length === 0) return;

    const title = senderRole === "worker" ? "رسالة جديدة من العامل" : "رسالة جديدة من العميل";
    const body = text.length > 100 ? `${text.substring(0, 100)}...` : text;

    const multicastMessage = {
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        type: "chat_message",
        chatId,
        requestId,
        senderId,
        senderRole,
      },
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

    if (invalidTokens.length > 0) {
      const batch = db.batch();
      invalidTokens.forEach((token) => {
        const ref = db
          .collection("users")
          .doc(receiverId)
          .collection("deviceTokens")
          .doc(token);
        batch.delete(ref);
      });
      await batch.commit();
    }

    await db.collection("users").doc(receiverId).collection("notifications").add({
      title,
      body,
      type: "chat_message",
      requestId,
      chatId,
      senderId,
      senderRole,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
);