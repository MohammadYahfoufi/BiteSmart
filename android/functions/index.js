const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.notifyDriverOnAssign = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if ((!before.driverId || before.driverId === '') && after.driverId && after.driverId !== '') {
    const db = getFirestore();
    const snap = await db.collection("users")
      .where("email", "==", after.driverId)
      .limit(1)
      .get();

    if (snap.empty) return;

    const driver = snap.docs[0].data();
    const token = driver.fcmToken;
    if (!token) return;

    const payload = {
      notification: {
        title: "🛵 New Delivery Assigned",
        body: "You have a new order to deliver!",
      },
    };

    await getMessaging().sendToDevice(token, payload);
    console.log("✅ Notification sent to:", after.driverId);
  }
});
