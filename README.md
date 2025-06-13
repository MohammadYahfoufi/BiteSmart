# 🍽️ BiteSmart – Flutter + Firebase Food Delivery App

**BiteSmart** is a cross-platform mobile food delivery app built with Flutter and Firebase.  
It supports real-time orders, delivery tracking, driver assignment, daily stock management, push notifications, and role-based access control for **Admins**, **Drivers**, and **Customers**.

---

## 👥 User Roles & Permissions

### 👤 Customer
- Register & login
- Browse food items
- Place orders (based on stock availability)
- Track driver location when assigned
- View order history
- In-app support (chatbot popup)

### 🚚 Driver
- Login with assigned credentials
- View orders assigned to them
- Mark orders as delivered
- Become unavailable once assigned
- Receive push notifications when assigned

### 🛠️ Admin
- View all customer orders
- Assign orders to available drivers
- Manage driver accounts (create, view, assign)
- View and manage food stock
- Reset daily stock from `defaultStock`
- Monitor order and delivery statuses in real time

---

## 📦 Key Features

### ✅ Real-Time Orders
- Orders placed by customers are immediately saved to Firestore.
- Admins see all pending and active orders live.
- Drivers receive assigned orders in real time via FCM.

### 📍 Delivery Tracking
- Once a driver is assigned, customers can track their location on a map.
- Location updates use Firestore and optional live location packages.

### 🔔 Push Notifications
- **FCM** is used to notify:
  - Drivers: when an order is assigned to them.
  - Customers: when their order is delivered.

### 🧮 Stock Management
- Each food item has:
  - `stock`: remaining stock for the day
  - `defaultStock`: the reset value to apply each morning

- Users can’t order more than available `stock`.
- A scheduled Firestore-triggered function or manual admin action resets `stock` to `defaultStock`.

### 🛑 Cart Validation
- Users cannot:
  - Place an order if the cart is empty
  - Exceed available stock
- A `SnackBar` warns them appropriately

---

## 🧠 Architecture

### 🔐 Authentication
- Firebase Authentication handles all login/registration.
- Each user has a `role` field (`admin`, `driver`, `customer`) stored in Firestore.

### 🗂️ Firestore Collections

```plaintext
users/
  {uid}/
    name
    role: admin | driver | customer
    email
    fcmToken

orders/
  {orderId}/
    items: [ {name, quantity, price, image} ]
    customerId
    driverId
    status: pending | assigned | delivered
    timestamp
    deliveryLocation (GeoPoint)

drivers/
  {uid}/
    name
    isAvailable: true/false

food/
  {foodId}/
    name
    price
    stock
    defaultStock
    category
    image
