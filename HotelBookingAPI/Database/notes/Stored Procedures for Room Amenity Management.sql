-- Stored Procedure for Fetching All RoomAmenities by RoomTypeID
CREATE OR ALTER PROCEDURE spFetchRoomAmenitiesByRoomTypeID
    @RoomTypeID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.AmenityID, a.Name, a.Description, a.IsActive
 FROM RoomAmenities ra
 JOIN Amenities a ON ra.AmenityID = a.AmenityID
 WHERE ra.RoomTypeID = @RoomTypeID;
END;
GO

-- Stored Procedure for Fetching All RoomTypes by AmenityID
CREATE OR ALTER PROCEDURE spFetchRoomTypesByAmenityID
    @AmenityID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT rt.RoomTypeID, rt.TypeName, rt.Description, rt.AccessibilityFeatures, rt.IsActive
 FROM RoomAmenities ra
 JOIN RoomTypes rt ON ra.RoomTypeID = rt.RoomTypeID
 WHERE ra.AmenityID = @AmenityID;
END;
GO

-- Insert Procedure for RoomAmenities
CREATE OR ALTER PROCEDURE spAddRoomAmenity
    @RoomTypeID INT,
    @AmenityID INT,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM RoomTypes WHERE RoomTypeID = @RoomTypeID) OR
               NOT EXISTS (SELECT 1 FROM Amenities WHERE AmenityID = @AmenityID)
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Room type or amenity does not exist.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM RoomAmenities WHERE RoomTypeID = @RoomTypeID AND AmenityID = @AmenityID)
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'This room amenity link already exists.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            INSERT INTO RoomAmenities (RoomTypeID, AmenityID)
            VALUES (@RoomTypeID, @AmenityID);

            SET @Status = 1; -- Success
            SET @Message = 'Room amenity added successfully.';
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Deleting a Single RoomAmenities based on RoomTypeID and AmenityID
CREATE OR ALTER PROCEDURE spDeleteSingleRoomAmenity
    @RoomTypeID INT,
    @AmenityID INT,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            DECLARE @Exists BIT;
            SELECT @Exists = COUNT(*) FROM RoomAmenities WHERE RoomTypeID = @RoomTypeID AND AmenityID = @AmenityID;

            IF @Exists = 0
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'The specified RoomTypeID and AmenityID combination does not exist.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Delete the specified room amenity
            DELETE FROM RoomAmenities
            WHERE RoomTypeID = @RoomTypeID AND AmenityID = @AmenityID;

            SET @Status = 1; -- Success
            SET @Message = 'Room amenity deleted successfully.';
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Create a User-Defined Table Type
-- This type will be used to pass multiple Amenity IDs as a single parameter to the stored procedures.
CREATE TYPE AmenityIDTableType AS TABLE (AmenityID INT);
GO

-- Stored Procedure for Bulk Insert into RoomAmenities for a Single RoomTypeID
CREATE OR ALTER PROCEDURE spBulkInsertRoomAmenities
    @RoomTypeID INT,
    @AmenityIDs AmenityIDTableType READONLY,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Check if the RoomTypeID exists
            IF NOT EXISTS (SELECT 1 FROM RoomTypes WHERE RoomTypeID = @RoomTypeID)
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Room type does not exist.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Check if all AmenityIDs exist
            IF EXISTS (SELECT 1 FROM @AmenityIDs WHERE AmenityID NOT IN (SELECT AmenityID FROM Amenities))
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'One or more amenities do not exist.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Insert AmenityIDs that do not already exist for the given RoomTypeID
            INSERT INTO RoomAmenities (RoomTypeID, AmenityID)
            SELECT @RoomTypeID, a.AmenityID 
            FROM @AmenityIDs a
            WHERE NOT EXISTS (
                SELECT 1 
                FROM RoomAmenities ra
                WHERE ra.RoomTypeID = @RoomTypeID AND ra.AmenityID = a.AmenityID
            );

            SET @Status = 1; -- Success
            SET @Message = 'Room amenities added successfully.';
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Stored Procedure for Bulk Update in RoomAmenities of a single @RoomTypeID
CREATE OR ALTER PROCEDURE spBulkUpdateRoomAmenities
    @RoomTypeID INT,
    @AmenityIDs AmenityIDTableType READONLY,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM RoomTypes WHERE RoomTypeID = @RoomTypeID)
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Room type does not exist.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @Count INT;
            SELECT @Count = COUNT(*) FROM Amenities WHERE AmenityID IN (SELECT AmenityID FROM @AmenityIDs);
            IF @Count <> (SELECT COUNT(*) FROM @AmenityIDs)
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'One or more amenities do not exist.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DELETE FROM RoomAmenities WHERE RoomTypeID = @RoomTypeID;

            INSERT INTO RoomAmenities (RoomTypeID, AmenityID)
            SELECT @RoomTypeID, AmenityID FROM @AmenityIDs;

            SET @Status = 1; -- Success
            SET @Message = 'Room amenities updated successfully.';
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Deleting All RoomAmenities of a Single RoomTypeID
CREATE OR ALTER PROCEDURE spDeleteAllRoomAmenitiesByRoomTypeID
    @RoomTypeID INT,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Delete all amenities for the specified room type
            DELETE FROM RoomAmenities WHERE RoomTypeID = @RoomTypeID;

            SET @Status = 1; -- Success
            SET @Message = 'All amenities for the room type have been deleted successfully.';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Deleting All RoomAmenities of a Single AmenityID
CREATE OR ALTER PROCEDURE spDeleteAllRoomAmenitiesByAmenityID
    @AmenityID INT,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Delete all amenities for the specified Amenity ID
            DELETE FROM RoomAmenities WHERE AmenityID = @AmenityID;

            SET @Status = 1; -- Success
            SET @Message = 'All amenities for the Amenity ID have been deleted successfully.';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END;
GO