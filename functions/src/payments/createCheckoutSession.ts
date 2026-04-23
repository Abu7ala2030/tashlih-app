import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import fetch from "node-fetch";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

type PaymentSessionData = {
  invoiceId: string;
  requestId?: string;
  customerId?: string;
  workerId?: string;
  driverId?: string;
  provider: string;
  method: string;
  amount: number;
  currency: string;
  status: string;
  checkoutUrl?: string;
  providerReference?: string;
  createdBy?: string;
};

type InvoiceData = {
  invoiceNumber?: string;
  requestId?: string;
  customerId?: string;
  workerId?: string;
  city?: string;
  partName?: string;
  totalAmount?: number;
  shippingFee?: number;
  discountAmount?: number;
  currency?: string;
};

function getEnv(name: string): string {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value.trim();
}

async function createTabbyCheckout(
  sessionId: string,
  session: PaymentSessionData,
  invoice: InvoiceData,
) {
  const baseUrl = process.env.TABBY_BASE_URL?.trim() || "https://api.tabby.sa";
  const secret = getEnv("TABBY_SECRET_KEY");
  const merchantCode = getEnv("TABBY_MERCHANT_CODE");

  const payload = {
    payment: {
      amount: String(session.amount),
      currency: session.currency || "SAR",
      buyer: {
        name: "Customer",
        email: "customer@example.com",
        phone: "0500000000",
      },
      shipping_address: {
        city: invoice.city || "Saudi Arabia",
        address: invoice.city || "Saudi Arabia",
        zip: "00000",
      },
      order: {
        reference_id: invoice.invoiceNumber || sessionId,
        items: [
          {
            title: invoice.partName || "Auto part",
            quantity: 1,
            unit_price: String(session.amount),
            category: "Auto Parts",
            reference_id: session.requestId || sessionId,
          },
        ],
        tax_amount: "0.00",
        shipping_amount: String(invoice.shippingFee ?? 0),
        discount_amount: String(invoice.discountAmount ?? 0),
      },
      description: `Invoice ${invoice.invoiceNumber || sessionId}`,
      meta: {
        invoice_id: session.invoiceId,
        request_id: session.requestId || "",
        session_id: sessionId,
      },
    },
    lang: "en",
    merchant_code: merchantCode,
    merchant_urls: {
      success: "https://example.com/payment/success",
      cancel: "https://example.com/payment/cancel",
      failure: "https://example.com/payment/failure",
    },
    token: null,
  };

  const response = await fetch(`${baseUrl}/api/v2/checkout`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secret}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data: any = await response.json();

  if (!response.ok) {
    throw new Error(
      `Tabby checkout failed: ${response.status} ${JSON.stringify(data)}`,
    );
  }

  const checkoutUrl =
    data?.configuration?.available_products?.installments?.[0]?.web_url || "";

  return {
    checkoutUrl,
    providerSessionId: data?.id || "",
    providerOrderId: data?.payment?.id || "",
    providerStatus: data?.status || "initiated",
    raw: data,
  };
}

async function createTamaraCheckout(
  sessionId: string,
  session: PaymentSessionData,
  invoice: InvoiceData,
) {
  const baseUrl =
    process.env.TAMARA_BASE_URL?.trim() || "https://api-sandbox.tamara.co";
  const secret = getEnv("TAMARA_API_TOKEN");

  const payload = {
    total_amount: {
      amount: session.amount,
      currency: session.currency || "SAR",
    },
    shipping_amount: {
      amount: invoice.shippingFee ?? 0,
      currency: session.currency || "SAR",
    },
    tax_amount: {
      amount: 0,
      currency: session.currency || "SAR",
    },
    order_reference_id: invoice.invoiceNumber || sessionId,
    order_number: session.requestId || sessionId,
    description: `Invoice ${invoice.invoiceNumber || sessionId}`,
    country_code: "SA",
    payment_type: "PAY_BY_INSTALMENTS",
    locale: "en_US",
    items: [
      {
        reference_id: session.requestId || sessionId,
        type: "Auto Part",
        name: invoice.partName || "Auto part",
        sku: session.requestId || sessionId,
        quantity: 1,
        unit_price: {
          amount: session.amount,
          currency: session.currency || "SAR",
        },
        tax_amount: {
          amount: 0,
          currency: session.currency || "SAR",
        },
        total_amount: {
          amount: session.amount,
          currency: session.currency || "SAR",
        },
      },
    ],
    consumer: {
      first_name: "Customer",
      last_name: "User",
      phone_number: "0500000000",
      email: "customer@example.com",
    },
    shipping_address: {
      first_name: "Customer",
      last_name: "User",
      line1: invoice.city || "Saudi Arabia",
      city: invoice.city || "Saudi Arabia",
      country_code: "SA",
      phone_number: "0500000000",
    },
    billing_address: {
      first_name: "Customer",
      last_name: "User",
      line1: invoice.city || "Saudi Arabia",
      city: invoice.city || "Saudi Arabia",
      country_code: "SA",
      phone_number: "0500000000",
    },
    merchant_url: {
      success: "https://example.com/payment/success",
      failure: "https://example.com/payment/failure",
      cancel: "https://example.com/payment/cancel",
      notification: "https://example.com/payment/webhook",
    },
  };

  const response = await fetch(`${baseUrl}/checkout`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secret}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data: any = await response.json();

  if (!response.ok) {
    throw new Error(
      `Tamara checkout failed: ${response.status} ${JSON.stringify(data)}`,
    );
  }

  return {
    checkoutUrl: data?.checkout_url || "",
    providerSessionId: data?.checkout_id || "",
    providerOrderId: data?.order_id || "",
    providerStatus: data?.status || "initiated",
    raw: data,
  };
}

export const createCheckoutSession = onDocumentCreated(
  "payment_sessions/{sessionId}",
  async (event) => {
    const sessionId = event.params.sessionId;
    const snap = event.data;

    if (!snap) return;

    const session = snap.data() as PaymentSessionData;
    if (!session?.invoiceId || !session?.provider) return;

    const invoiceRef = db.collection("invoices").doc(session.invoiceId);
    const invoiceSnap = await invoiceRef.get();

    if (!invoiceSnap.exists) {
      await snap.ref.set(
        {
          status: "failed",
          errorMessage: "Invoice not found",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    const invoice = invoiceSnap.data() as InvoiceData;

    try {
      let result: {
        checkoutUrl: string;
        providerSessionId: string;
        providerOrderId: string;
        providerStatus: string;
        raw: any;
      };

      if (session.provider === "tabby") {
        result = await createTabbyCheckout(sessionId, session, invoice);
      } else if (session.provider === "tamara") {
        result = await createTamaraCheckout(sessionId, session, invoice);
      } else {
        result = {
          checkoutUrl: "",
          providerSessionId: "",
          providerOrderId: "",
          providerStatus: "pending_manual_payment",
          raw: {},
        };
      }

      await snap.ref.set(
        {
          status: result.providerStatus || "created",
          checkoutUrl: result.checkoutUrl || "",
          providerSessionId: result.providerSessionId || "",
          providerOrderId: result.providerOrderId || "",
          rawResponse: result.raw || {},
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await invoiceRef.set(
        {
          paymentProvider: session.provider,
          paymentMethod: session.method,
          paymentSessionId: sessionId,
          paymentStatus:
            session.provider === "card" || session.provider === "cod"
              ? "pending_manual_payment"
              : "initiated",
          status:
            session.provider === "card" || session.provider === "cod"
              ? "unpaid"
              : "unpaid",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      if (session.requestId) {
        await db.collection("requests").doc(session.requestId).set(
          {
            paymentProvider: session.provider,
            paymentMethod: session.method,
            paymentSessionId: sessionId,
            paymentStatus:
              session.provider === "card" || session.provider === "cod"
                ? "pending_manual_payment"
                : "initiated",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    } catch (error: any) {
      await snap.ref.set(
        {
          status: "failed",
          errorMessage: error?.message || "Unknown payment error",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await invoiceRef.set(
        {
          paymentStatus: "failed",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      if (session.requestId) {
        await db.collection("requests").doc(session.requestId).set(
          {
            paymentStatus: "failed",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }
  },
);