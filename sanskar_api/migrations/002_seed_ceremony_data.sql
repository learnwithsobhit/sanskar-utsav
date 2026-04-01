-- Sanskar Utsav — Seed Data
-- Sample ceremony schedule & initial admin guest

-- ═══════════════════════════════════════════════
-- ADMIN GUEST (family host)
-- ═══════════════════════════════════════════════

INSERT INTO guests (invite_code, name, phone, relation, family_side, is_admin, status)
VALUES
    ('ADMIN2026', 'Shobhit Chaturvedi', '+919999999999', 'Father', 'paternal', TRUE, 'confirmed'),
    ('SHRIHAN26', 'Shrihan Chaturvedi', '', 'Yajman (Son)', 'paternal', FALSE, 'confirmed')
ON CONFLICT (invite_code) DO NOTHING;

-- ═══════════════════════════════════════════════
-- SAMPLE CEREMONY EVENTS (5-day program)
-- Update dates when finalized
-- ═══════════════════════════════════════════════

INSERT INTO ceremony_events (day_number, title, hindi_title, description, event_date, start_time, end_time, venue, dress_code, category, icon_emoji, sort_order)
VALUES
    -- Day 1: Preparations & Welcome
    (1, 'Ganesh Sthapana & Matrika Puja', 'गणेश स्थापना एवं मातृका पूजा',
     'Invocation of Lord Ganesh and establishment of sacred Matrika deities to begin the auspicious ceremonies.',
     '2026-05-15', '07:00', '09:00', 'Home — Puja Mandap', 'Traditional White/Yellow', 'ritual', '🕉️', 1),

    (1, 'Nandi Shraddha', 'नांदी श्राद्ध',
     'Sacred ritual honoring ancestors and seeking their blessings for the ceremony.',
     '2026-05-15', '09:30', '11:00', 'Home — Puja Mandap', 'Traditional White', 'ritual', '🙏', 2),

    (1, 'Welcome Dinner & Mehendi', 'स्वागत भोज एवं मेहंदी',
     'Welcome gathering for all guests with traditional dinner and mehendi celebrations.',
     '2026-05-15', '18:00', '22:00', 'Banquet Hall', 'Festive Colorful', 'celebration', '🎉', 3),

    -- Day 2: Core Ceremonies
    (2, 'Mandap Puja & Havan', 'मंडप पूजा एवं हवन',
     'Consecration of the sacred mandap followed by the holy fire ceremony.',
     '2026-05-16', '06:00', '09:00', 'Home — Puja Mandap', 'Traditional Yellow', 'ritual', '🔥', 1),

    (2, 'Chudakarma & Mundan', 'चूड़ाकर्म एवं मुंडन',
     'Sacred tonsure ceremony — an important pre-upanayana rite.',
     '2026-05-16', '10:00', '11:30', 'Home — Puja Mandap', 'Traditional White', 'ritual', '✂️', 2),

    (2, 'Family Lunch', 'पारिवारिक भोज',
     'Traditional vegetarian feast for all family members and guests.',
     '2026-05-16', '12:30', '14:30', 'Dining Area', 'Comfortable Traditional', 'feast', '🍽️', 3),

    -- Day 3: The Main Ceremony
    (3, 'Yogyopaveet Sanskar (Main Ceremony)', 'यज्ञोपवीत संस्कार (मुख्य कार्यक्रम)',
     'The sacred thread ceremony — Shrihan receives the Yajnopavita (sacred thread) and is initiated into Gayatri Mantra. The most auspicious moment of the entire celebration.',
     '2026-05-17', '06:00', '12:00', 'Home — Puja Mandap', 'Traditional Yellow/Saffron', 'ritual', '🪔', 1),

    (3, 'Bhiksha (Seeking Alms)', 'भिक्षा',
     'Newly initiated Brahmachari seeks alms from mother and family members — a symbolic rite of humility and learning.',
     '2026-05-17', '12:00', '13:00', 'Home', 'Traditional', 'ritual', '🙏', 2),

    (3, 'Grand Feast & Celebrations', 'महाभोज एवं उत्सव',
     'Grand celebration lunch for all guests marking the completion of the main ceremony.',
     '2026-05-17', '13:00', '16:00', 'Banquet Hall', 'Festive Traditional', 'feast', '🎊', 3),

    (3, 'Cultural Evening & Sangeet', 'सांस्कृतिक संध्या एवं संगीत',
     'Evening of music, dance and cultural performances by family and friends.',
     '2026-05-17', '18:00', '22:00', 'Banquet Hall', 'Festive / Semi-formal', 'celebration', '🎶', 4),

    -- Day 4: Post-Ceremony Rituals
    (4, 'Surya Darshan & Gayatri Japa', 'सूर्य दर्शन एवं गायत्री जप',
     'Morning sun salutation and Gayatri mantra recitation by the newly initiated Brahmachari.',
     '2026-05-18', '05:30', '07:00', 'Home — Terrace', 'Traditional White', 'ritual', '☀️', 1),

    (4, 'Samidha Daan Havan', 'समिधा दान हवन',
     'Post-initiation fire ceremony with sacred wood offerings.',
     '2026-05-18', '07:30', '09:00', 'Home — Puja Mandap', 'Traditional', 'ritual', '🔥', 2),

    (4, 'Family Photo Session', 'पारिवारिक फोटो सत्र',
     'Professional photography session with all family groups.',
     '2026-05-18', '10:00', '12:00', 'Garden Area', 'Best Traditional Attire', 'celebration', '📸', 3),

    (4, 'Farewell Lunch', 'विदाई भोज',
     'Farewell lunch for departing guests with blessings and gift giving.',
     '2026-05-18', '12:30', '15:00', 'Dining Area', 'Comfortable', 'feast', '🎁', 4),

    -- Day 5: Conclusion
    (5, 'Visarjan & Closing Puja', 'विसर्जन एवं समापन पूजा',
     'Immersion of sacred items and concluding prayers marking the blessed end of the ceremony.',
     '2026-05-19', '07:00', '09:00', 'Home — Puja Mandap', 'Traditional White', 'ritual', '🙏', 1),

    (5, 'Ashirvad Sabha', 'आशीर्वाद सभा',
     'Blessing assembly where elders bestow their blessings upon Shrihan.',
     '2026-05-19', '10:00', '12:00', 'Home', 'Traditional', 'ritual', '🙏', 2)
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════
-- SAMPLE GUESTS (for testing)
-- ═══════════════════════════════════════════════

INSERT INTO guests (invite_code, name, phone, relation, family_side, status, city)
VALUES
    ('DADA2026', 'Dadaji Chaturvedi', '', 'Grandfather', 'paternal', 'confirmed', 'Varanasi'),
    ('DADI2026', 'Dadiji Chaturvedi', '', 'Grandmother', 'paternal', 'confirmed', 'Varanasi'),
    ('NANA2026', 'Nanaji', '', 'Grandfather', 'maternal', 'confirmed', 'Lucknow'),
    ('NANI2026', 'Naniji', '', 'Grandmother', 'maternal', 'confirmed', 'Lucknow'),
    ('MAMA2026', 'Mamaji', '', 'Mama', 'maternal', 'invited', 'Delhi'),
    ('CHACHA026', 'Chachaji', '', 'Chacha', 'paternal', 'invited', 'Mumbai'),
    ('FRIEND01', 'Rahul Sharma', '', 'Friend', 'both', 'invited', 'Bangalore'),
    ('FRIEND02', 'Amit Verma', '', 'Friend', 'both', 'invited', 'Pune')
ON CONFLICT (invite_code) DO NOTHING;

-- ═══════════════════════════════════════════════
-- SAMPLE ANNOUNCEMENTS
-- ═══════════════════════════════════════════════

INSERT INTO announcements (title, message, category, priority, is_active)
VALUES
    ('🙏 Welcome to Shrihan''s Yogyopaveet Sanskar', 'We are blessed to invite you to celebrate this sacred milestone. Please check the schedule for detailed program information.', 'general', 0, TRUE),
    ('🅿️ Parking Arrangements', 'Designated parking is available at the community hall. Valet service available for Day 3 (Main Ceremony).', 'transport', 0, TRUE),
    ('🍽️ All Meals are Pure Vegetarian', 'As per tradition, all meals during the ceremony are Sattvic vegetarian. If you have specific dietary needs (Jain, vegan), please update your profile.', 'food', 1, TRUE)
ON CONFLICT DO NOTHING;
