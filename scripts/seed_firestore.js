/**
 * Firestore Seed Script for tashlih_app
 * Safe + Idempotent (uses merge)
 */

const admin = require("firebase-admin");

// ======== CONFIG ========
const args = process.argv.slice(2);

const getArg = (name) => {
  const found = args.find((a) => a.startsWith(`--${name}=`));
  return found ? found.split("=")[1] : null;
};

const serviceAccountPath = getArg("serviceAccount");
const dryRun = args.includes("--dry-run");

if (!serviceAccountPath) {
  console.error("❌ Missing --serviceAccount=path/to/key.json");
  process.exit(1);
}

// ======== INIT ========
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ======== HELPERS ========
const log = (...args) => console.log("👉", ...args);

const setDoc = async (ref, data) => {
  if (dryRun) {
    log("[DRY-RUN] Set:", ref.path);
    return;
  }
  await ref.set(data, { merge: true });
};

// ======== MAIN ========
async function run() {
  log("Starting seed...");

  // ======== USERS ========
  const usersSnap = await db.collection("users").get();

  let customer = null;
  let worker = null;
  let driver = null;

  usersSnap.forEach((doc) => {
    const u = doc.data();
    if (u.role === "customer" && !customer) customer = { id: doc.id, ...u };
    if (u.role === "worker" && !worker) worker = { id: doc.id, ...u };
    if (u.role === "driver" && !driver) driver = { id: doc.id, ...u };
  });

  if (!customer || !worker || !driver) {
    console.error("❌ تحتاج users فيها roles: customer / worker / driver");
    process.exit(1);
  }

  log("Users detected:", customer.id, worker.id, driver.id);

  // ======== WORKERS / DRIVERS ========
  await setDoc(db.collection("workers").doc(worker.id), {
    userId: worker.id,
    name: worker.name || "عامل",
    rating: 4.5,
    verified: true,
    completedJobs: 10,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await setDoc(db.collection("drivers").doc(driver.id), {
    userId: driver.id,
    name: driver.name || "سائق",
    isOnline: true,
    vehicleType: "pickup",
    rating: 4.7,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ======== REQUEST ========
  const requestId = "seed_request_1";

  await setDoc(db.collection("requests").doc(requestId), {
    customerId: customer.id,
    status: "assigned",
    title: "طلب تشليح - باب سيارة",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),

    workerId: worker.id,
    acceptedOfferId: "offer_1",
    acceptedOfferPrice: 250,
    commissionEligible: true,
  });

  // ======== OFFERS ========
  await setDoc(
    db.collection("requests").doc(requestId).collection("offers").doc("offer_1"),
    {
      workerId: worker.id,
      price: 250,
      status: "accepted",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  );

  await setDoc(
    db.collection("requests").doc(requestId).collection("offers").doc("offer_2"),
    {
      workerId: worker.id,
      price: 300,
      status: "rejected",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  );

  // ======== TIMELINE ========
  await setDoc(
    db.collection("requests").doc(requestId).collection("timeline").doc("t1"),
    {
      type: "created",
      message: "تم إنشاء الطلب",
      at: admin.firestore.FieldValue.serverTimestamp(),
    }
  );

  await setDoc(
    db.collection("requests").doc(requestId).collection("timeline").doc("t2"),
    {
      type: "assigned",
      message: "تم تعيين العامل",
      at: admin.firestore.FieldValue.serverTimestamp(),
    }
  );

  // ======== CHAT ========
  const chatId = "chat_1";

  await setDoc(db.collection("chats").doc(chatId), {
    requestId,
    customerId: customer.id,
    workerId: worker.id,
    participants: [customer.id, worker.id],
    lastMessage: "مرحبا",
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    unreadCount: {
      customer: 0,
      worker: 1,
    },
  });

  await setDoc(
    db.collection("chats").doc(chatId).collection("messages").doc("m1"),
    {
      senderId: customer.id,
      type: "text",
      text: "السلام عليكم",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  );

  await setDoc(
    db.collection("chats").doc(chatId).collection("messages").doc("m2"),
    {
      senderId: worker.id,
      type: "text",
      text: "وعليكم السلام",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  );

  // ======== INVOICE ========
  await setDoc(db.collection("invoices").doc("inv_1"), {
    requestId,
    customerId: customer.id,
    workerId: worker.id,
    amount: 250,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ======== COMMISSION ========
  await setDoc(db.collection("commissions").doc("com_1"), {
    requestId,
    workerId: worker.id,
    amount: 25,
    percentage: 10,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ======== TRANSACTION ========
  await setDoc(db.collection("financial_transactions").doc("txn_1"), {
    type: "invoice_payment",
    amount: 250,
    referenceId: "inv_1",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ======== PAYMENT SESSION ========
  await setDoc(db.collection("payment_sessions").doc("ps_1"), {
    requestId,
    amount: 250,
    provider: "cash",
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  log("✅ Seed completed");
}

run().catch((e) => {
  console.error("❌ Error:", e);
});