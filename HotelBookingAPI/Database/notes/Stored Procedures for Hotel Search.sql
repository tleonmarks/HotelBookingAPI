-- Search by Availability Dates
-- Searches rooms that are available between specified check-in and check-out dates.
-- Inputs: @CheckInDate - Desired check-in date, @CheckOutDate - Desired check-out date
-- Returns: List of rooms that are available along with their type details
CREATE OR ALTER PROCEDURE spSearchByAvailability
    @CheckInDate DATE,
    @CheckOutDate DATE
AS
BEGIN
    SET NOCOUNT ON; -- Suppresses the 'rows affected' message

    SELECT r.RoomID, r.RoomNumber, r.RoomTypeID, r.Price, r.BedType, r.ViewType, r.Status,
           rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    LEFT JOIN Reservations res ON r.RoomID = res.RoomID 
        AND res.Status NOT IN ('Cancelled')
        AND (
            (res.CheckInDate <= @CheckOutDate AND res.CheckOutDate >= @CheckInDate)
        )
    WHERE res.RoomID IS NULL AND r.Status NOT IN ('Under Maintenance')
    AND r.IsActive = 1;
END
GO

-- Search by Price Range
-- Searches rooms within a specified price range.
-- Inputs: @MinPrice - Minimum room price, @MaxPrice - Maximum room price
-- Returns: List of rooms within the price range along with their type details
CREATE OR ALTER PROCEDURE spSearchByPriceRange
    @MinPrice DECIMAL(10,2),
    @MaxPrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON; -- Avoids sending row count information
    SELECT r.RoomID, r.RoomNumber, r.Price, r.BedType, r.ViewType, r.Status,
           rt.RoomTypeID, rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    WHERE r.Price BETWEEN @MinPrice AND @MaxPrice
    AND r.IsActive = 1 AND rt.IsActive = 1
END
GO

-- Search by Room Type
-- Searches rooms based on room type name.
-- Inputs: @RoomTypeName - Name of the room type
-- Returns: List of rooms matching the room type name along with type details
CREATE OR ALTER PROCEDURE spSearchByRoomType
    @RoomTypeName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.RoomID, r.RoomNumber, r.Price, r.BedType, r.ViewType, r.Status,
           rt.RoomTypeID, rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    WHERE rt.TypeName = @RoomTypeName
    AND r.IsActive = 1
END
GO

-- Search by View Type
-- Searches rooms by specific view type.
-- Inputs: @ViewType - Type of view from the room (e.g., sea, city)
-- Returns: List of rooms with the specified view along with their type details
CREATE OR ALTER PROCEDURE spSearchByViewType
    @ViewType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.RoomID, r.RoomNumber, r.RoomTypeID, r.Price, r.BedType, r.Status, r.ViewType,
           rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    WHERE r.ViewType = @ViewType
    AND r.IsActive = 1
END
GO

-- Search by Amenities
-- Searches rooms offering a specific amenity.
-- Inputs: @AmenityName - Name of the amenity
-- Returns: List of rooms offering the specified amenity along with their type details
CREATE OR ALTER PROCEDURE spSearchByAmenities
    @AmenityName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT r.RoomID, r.RoomNumber, r.RoomTypeID, r.Price, r.BedType, r.ViewType, r.Status,
                    rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
 JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    JOIN RoomAmenities ra ON rt.RoomTypeID = ra.RoomTypeID
    JOIN Amenities a ON ra.AmenityID = a.AmenityID
    
    WHERE a.Name = @AmenityName
    AND r.IsActive = 1
END
GO

-- Search All Rooms by RoomTypeID
-- Searches all rooms based on a specific RoomTypeID.
-- Inputs: @RoomTypeID - The ID of the room type
-- Returns: List of all rooms associated with the specified RoomTypeID along with type details
CREATE OR ALTER PROCEDURE spSearchRoomsByRoomTypeID
    @RoomTypeID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.RoomID, r.RoomNumber, r.Price, r.BedType, r.ViewType, r.Status,
           rt.RoomTypeID, rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    WHERE rt.RoomTypeID = @RoomTypeID
    AND r.IsActive = 1
END
GO

-- Stored Procedure to Fetch Room, Room Type, and Amenities Details
-- Retrieves details of a room by its RoomID, including room type and amenities.
-- Inputs: @RoomID - The ID of the room
-- Returns: Details of the room, its room type, and associated amenities
CREATE OR ALTER PROCEDURE spGetRoomDetailsWithAmenitiesByRoomID
    @RoomID INT
AS
BEGIN
    SET NOCOUNT ON; -- Suppresses the 'rows affected' message

    -- First, retrieve the basic details of the room along with its room type information
    SELECT 
        r.RoomID, 
        r.RoomNumber, 
        r.Price, 
        r.BedType, 
        r.ViewType, 
        r.Status,
        rt.RoomTypeID, 
        rt.TypeName, 
        rt.AccessibilityFeatures, 
        rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    WHERE r.RoomID = @RoomID
    AND r.IsActive = 1;

    -- Next, retrieve the amenities associated with the room type of the specified room
    SELECT 
        a.AmenityID, 
        a.Name, 
        a.Description
    FROM RoomAmenities ra
    JOIN Amenities a ON ra.AmenityID = a.AmenityID
    WHERE ra.RoomTypeID IN (SELECT RoomTypeID FROM Rooms WHERE RoomID = @RoomID)
    AND a.IsActive = 1;
END
GO

-- Fetch Amenities for a Specific Room
-- Retrieves all amenities associated with a specific room by its RoomID.
-- Inputs: @RoomID - The ID of the room
-- Returns: List of amenities associated with the room type of the specified room
CREATE OR ALTER PROCEDURE spGetRoomAmenitiesByRoomID
    @RoomID INT
AS
BEGIN
    SET NOCOUNT ON; -- Suppresses the 'rows affected' message

    SELECT 
        a.AmenityID, 
        a.Name, 
        a.Description
    FROM RoomAmenities ra
    JOIN Amenities a ON ra.AmenityID = a.AmenityID
    JOIN Rooms r ON ra.RoomTypeID = r.RoomTypeID
    WHERE r.RoomID = @RoomID
    AND a.IsActive = 1;
END
GO

-- Search by Rating
-- Searches rooms based on a minimum average guest rating.
-- Inputs: @MinRating - Minimum average rating required
-- Searches rooms based on a minimum average guest rating.
-- Inputs: @MinRating - Minimum average rating required
CREATE OR ALTER PROCEDURE spSearchByMinRating
    @MinRating FLOAT
AS
BEGIN
    SET NOCOUNT ON;

    -- A subquery to calculate average ratings for each room via their reservations
    WITH RatedRooms AS (
        SELECT 
            res.RoomID,
            AVG(CAST(fb.Rating AS FLOAT)) AS AvgRating  -- Calculate average rating per room
        FROM Feedbacks fb
        JOIN Reservations res ON fb.ReservationID = res.ReservationID
        GROUP BY res.RoomID
        HAVING AVG(CAST(fb.Rating AS FLOAT)) >= @MinRating  -- Filter rooms by minimum rating
    )
    SELECT 
        r.RoomID, 
        r.RoomNumber, 
        r.Price, 
        r.BedType, 
        r.ViewType, 
        r.Status,
        rt.RoomTypeID, 
        rt.TypeName, 
        rt.AccessibilityFeatures, 
        rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    JOIN RatedRooms rr ON r.RoomID = rr.RoomID  -- Join with the subquery of rated rooms
    WHERE r.IsActive = 1;
END
GO

-- Custom Combination Searches with Dynamic SQL
-- Searches for rooms based on a combination of criteria including price range, room type, and amenities.
-- Inputs:
-- @MinPrice DECIMAL(10,2) = NULL: Minimum price filter (optional)
-- @MaxPrice DECIMAL(10,2) = NULL: Maximum price filter (optional)
-- @RoomTypeName NVARCHAR(50) = NULL: Room type Name filter (optional)
-- @AmenityName NVARCHAR(100) = NULL: Amenity Name filter (optional)
-- @@ViewType NVARCHAR(50) = NULL: View Type filter (optional)
-- Returns: List of rooms matching the combination of specified criteria along with their type details
-- Note: Based on the Requirements you can use AND or OR Conditions
CREATE OR ALTER PROCEDURE spSearchCustomCombination
    @MinPrice DECIMAL(10,2) = NULL,
    @MaxPrice DECIMAL(10,2) = NULL,
    @RoomTypeName NVARCHAR(50) = NULL,
    @AmenityName NVARCHAR(100) = NULL,
    @ViewType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON; -- Suppresses the 'rows affected' message

    DECLARE @SQL NVARCHAR(MAX)
    SET @SQL = 'SELECT DISTINCT r.RoomID, r.RoomNumber, r.Price, r.BedType, r.ViewType, r.Status, 
                               rt.RoomTypeID, rt.TypeName, rt.AccessibilityFeatures, rt.Description 
                FROM Rooms r
                JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
                LEFT JOIN RoomAmenities ra ON rt.RoomTypeID = ra.RoomTypeID
                LEFT JOIN Amenities a ON ra.AmenityID = a.AmenityID
                WHERE r.IsActive = 1 '

    DECLARE @Conditions NVARCHAR(MAX) = ''

    -- Dynamic conditions based on input parameters
    IF @MinPrice IS NOT NULL
        SET @Conditions = @Conditions + 'AND r.Price >= @MinPrice '
    IF @MaxPrice IS NOT NULL
        SET @Conditions = @Conditions + 'AND r.Price <= @MaxPrice '
    IF @RoomTypeName IS NOT NULL
        SET @Conditions = @Conditions + 'AND rt.TypeName LIKE ''%' + @RoomTypeName + '%'' '
    IF @AmenityName IS NOT NULL
        SET @Conditions = @Conditions + 'AND a.Name LIKE ''%' + @AmenityName + '%'' '
    IF @ViewType IS NOT NULL
        SET @Conditions = @Conditions + 'AND r.ViewType = @ViewType '

    -- Remove the first OR if any conditions were added
    IF LEN(@Conditions) > 0
        SET @SQL = @SQL + ' AND (' + STUFF(@Conditions, 1, 3, '') + ')'

    -- Execute the dynamic SQL
    EXEC sp_executesql @SQL,
                       N'@MinPrice DECIMAL(10,2), @MaxPrice DECIMAL(10,2), @RoomTypeName NVARCHAR(50), @AmenityName NVARCHAR(100), @ViewType NVARCHAR(50)',
                       @MinPrice, @MaxPrice, @RoomTypeName, @AmenityName, @ViewType
END
GO