-- Inserting Data into UserRoles table
INSERT INTO UserRoles (RoleName, Description) VALUES
('Admin', 'Administrator with full access'),
('Guest', 'Guest user with limited access'), -- You can replace Guest with User also
('Manager', 'Hotel manager with extended privileges');

-- Inserting Data into Countries and States tables
-- Insert Countries
INSERT INTO Countries (CountryName, CountryCode) VALUES
('India', 'IN'),
('USA', 'US'),
('UK', 'GB');

-- Assuming the IDs for countries are 1 for India, 2 for USA, and 3 for UK
-- Insert States
INSERT INTO States (StateName, CountryID) VALUES
('Maharashtra', 1),
('Delhi', 1),
('Texas', 2),
('California', 2),
('England', 3),
('Scotland', 3);

-- Inserting Data into RoomTypes table
INSERT INTO RoomTypes (TypeName, AccessibilityFeatures, Description, CreatedBy, ModifiedBy) VALUES
('Standard', 'Wheelchair ramps, Grab bars in bathroom', 'Basic room with essential amenities', 'System', 'System'),
('Deluxe', 'Wheelchair accessible, Elevator access', 'High-end room with luxurious amenities', 'System', 'System'),
('Executive', 'Wide door frames, Accessible bathroom', 'Room for business travelers with a work area', 'System', 'System'),
('Family', 'Child-friendly facilities, Safety features', 'Spacious room for families with children', 'System', 'System');

-- Inserting Data into Rooms table
-- Assuming the IDs for room types are 1 for Standard, 2 for Deluxe, 3 for Executive, and 4 for Family
INSERT INTO Rooms (RoomNumber, RoomTypeID, Price, BedType, ViewType, Status, CreatedBy, ModifiedBy) VALUES
('101', 1, 100.00, 'Queen', 'Sea', 'Available', 'System', 'System'),
('102', 1, 100.00, 'Queen', 'City', 'Under Maintenance', 'System', 'System'),
('201', 2, 150.00, 'King', 'Garden', 'Occupied', 'System', 'System'),
('301', 3, 200.00, 'King', 'Sea', 'Available', 'System', 'System'),
('401', 4, 250.00, 'Twin', 'Pool', 'Occupied', 'System', 'System');

-- Inserting Data into Amenities table
INSERT INTO Amenities (Name, Description, CreatedBy, ModifiedBy) VALUES
('Wi-Fi', 'High-speed wireless internet access', 'System', 'System'),
('Pool', 'Outdoor swimming pool with lifeguard', 'System', 'System'),
('SPA', 'Full-service spa and wellness center', 'System', 'System'),
('Fitness Center', 'Gym with modern equipment', 'System', 'System');

-- Linking Room Types with Amenities
-- Assuming the IDs for amenities are 1 for Wi-Fi, 2 for Pool, 3 for SPA, and 4 for Fitness Center
INSERT INTO RoomAmenities (RoomTypeID, AmenityID) VALUES
(1, 1), (1, 4),  -- Standard rooms have Wi-Fi and access to Fitness Center
(2, 1), (2, 2), (2, 3), (2, 4),  -- Deluxe rooms have all amenities
(3, 1), (3, 4),  -- Executive rooms have Wi-Fi and Fitness Center
(4, 1), (4, 2), (4, 3), (4, 4);  -- Family rooms have all amenities

-- Inserting Data into RefundMethods table
INSERT INTO RefundMethods (MethodName) VALUES
('Cash'),
('Credit Card'),
('Online Transfer'),
('Check');