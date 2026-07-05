INSERT INTO hotel_bookings (
    org_id,
    hotel_id,
    city,
    checkin_date,
    checkout_date,
    amount,
    status,
    created_at
)
SELECT
    uuid_generate_v4(),
    'HOTEL-' || gs,
    (ARRAY['delhi','mumbai','bangalore','hyderabad'])[floor(random()*4)+1],
    CURRENT_DATE - (random()*30)::int,
    CURRENT_DATE + (random()*5)::int,
    (random()*5000 + 1000)::numeric(12,2),
    (ARRAY['confirmed','cancelled','completed'])[floor(random()*3)+1],
    NOW() - (random()* interval '30 days')
FROM generate_series(1,100) gs;

INSERT INTO booking_events (
    booking_id,
    event_type,
    payload,
    created_at
)
SELECT
    id,
    'BOOKING_CREATED',
    '{"status":"created"}'::jsonb,
    NOW()
FROM hotel_bookings
LIMIT 50;