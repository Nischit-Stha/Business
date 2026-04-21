# Data Model (Rentals)

## Core Tables

- `customers`: profile and contact data only
- `vehicles`: fleet inventory and availability state
- `booking_requests`: request/event records only
- `invoices`: billing and payment tracking
- `offers` + `offer_messages`: negotiation flow
- `payment_intents`: payment intent lifecycle

## Booking Request Status

Production target values:

- `submitted`
- `under_review`
- `approved`
- `completed`
- `rejected`

## Key Constraints

- `booking_requests.request_type` in (`pickup`, `dropoff`, `swap`)
- `vehicles.status` in (`available`, `rented`, `maintenance`)
- required customer identifier on requests (`phone`, `email`, or `customer_id`)

## Key Indexes

- `vehicles.plate`
- `customers.phone`
- `customers.email`
- `booking_requests.status`
- `booking_requests.customer_id`
