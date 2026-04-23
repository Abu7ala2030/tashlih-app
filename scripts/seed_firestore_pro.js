/**
 * Advanced Firestore Seed Script (Production-like)
 */

const admin = require("firebase-admin");

// ===== CONFIG =====
const args = process.argv.slice(2);
const getArg = (name) => {
  const found = args.find((a) => a.startsWith(`--${name}=`));
  return found ? found.split("=")[1] : null;
};

const serviceAccountPath = getArg("serviceAccount");
const dryRun = args.includes("--dry-run");

if (!serviceAccountPath) {
  console.error("❌ Missing --serviceAccount");
  process.exit(1);
}

// ===== INIT =====
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ===== HELPERS =====
const log = (...args) => console.log("👉", ...args);

const setDoc = async (ref, data) => {
  if (dryRun) {
    log("[DRY-RUN]", ref.path);
    return;
  }
  await ref.set(data, { merge: true });
};

// ===== MAIN =====
async function run() {
  log("Seeding started...");

  const usersSnap = await db.collection("users").get();

  const customers = [];
  const workers = [];
  const drivers = [];

  usersSnap.forEach((doc) => {
    const u = doc.data();
    if (u.role === "customer") customers.push({ id: doc.id, ...u });
    if (u.role === "worker") workers.push({ id: doc.id, ...u });
    if (u.role === "driver") drivers.push({ id: doc.id, ...u });
  });

  if (!customers.length || !workers.length || !drivers.length) {
    console.error("❌ لازم users فيها customer + worker + driver");
    process.exit(1);
  }

  // ===== WORKERS & DRIVERS =====
  for (let w of workers) {
    await setDoc(db.collection("workers").doc(w.id), {
      userId: w.id,
      name: w.name || "عامل",
      rating: 4 + Math.random(),
      verified: true,
      completedJobs: Math.floor(Math.random() * 50),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  for (let d of drivers) {
    await setDoc(db.collection("drivers").doc(d.id), {
      userId: d.id,
      name: d.name || "سائق",
      isOnline: true,
      vehicleType: "pickup",
      rating: 4 + Math.random(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // ===== REQUESTS =====
  const statuses = ["pending", "assigned", "shipped", "delivered", "cancelled"];

  for (let i = 1; i <= 10; i++) {
    const customer = customers[i % customers.length];
    const worker = workers[i % workers.length];

    const requestId = `req_${i}`;
    const status = statuses[i % statuses.length];

    await setDoc(db.collection("requests").doc(requestId), {
      customerId: customer.id,
      workerId: status !== "pending" ? worker.id : null,
      status,
      title: `طلب رقم ${i}`,
      description: "قطع غيار سيارة",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedOfferId: status !== "pending" ? "offer_1" : null,
      acceptedOfferPrice: status !== "pending" ? 200 + i * 10 : null,
      commissionEligible: status === "delivered",
    });

    // ===== OFFERS =====
    await setDoc(
      db.collection("requests").doc(requestId).collection("offers").doc("offer_1"),
      {
        workerId: worker.id,
        price: 200 + i * 10,
        status: status !== "pending" ? "accepted" : "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );

    await setDoc(
      db.collection("requests").doc(requestId).collection("offers").doc("offer_2"),
      {
        workerId: worker.id,
        price: 250 + i * 10,
        status: "rejected",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );

    // ===== TIMELINE =====
    await setDoc(
      db.collection("requests").doc(requestId).collection("timeline").doc("t1"),
      {
        type: "created",
        message: "تم إنشاء الطلب",
        at: admin.firestore.FieldValue.serverTimestamp(),
      }
    );

    if (status !== "pending") {
      await setDoc(
        db.collection("requests").doc(requestId).collection("timeline").doc("t2"),
        {
          type: "assigned",
          message: "تم تعيين العامل",
          at: admin.firestore.FieldValue.serverTimestamp(),
        }
      );
    }

    // ===== CHAT =====
    if (status !== "pending") {
      const chatId = `chat_${i}`;

      await setDoc(db.collection("chats").doc(chatId), {
        requestId,
        customerId: customer.id,
        workerId: worker.id,
        participants: [customer.id, worker.id],
        lastMessage: "مرحبا",
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
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
    }

    // ===== INVOICE / COMMISSION =====
    if (status === "delivered") {
      await setDoc(db.collection("invoices").doc(`inv_${i}`), {
        requestId,
        amount: 200 + i * 10,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await setDoc(db.collection("commissions").doc(`com_${i}`), {
        requestId,
        amount: 20,
        percentage: 10,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await setDoc(db.collection("financial_transactions").doc(`txn_${i}`), {
        type: "invoice_payment",
        amount: 200 + i * 10,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await setDoc(db.collection("payment_sessions").doc(`ps_${i}`), {
        requestId,
        amount: 200 + i * 10,
        provider: i % 2 === 0 ? "tabby" : "tamara",
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  log("✅ Seed completed successfully");
}

run().catch(console.error);