-- This SQL command retrieves the name of the foreign key constraint related to RoomID in the Reservations table
--Reservations Table:
--In order to manage the reservations efficiently, especially when dealing with multiple rooms per reservation, we need to create a separate table. We will create a new table that will store the Reservation ID, with multiple entries for RoomId. Let us proceed and first make the changes.
--Remove the RoomID and NumberOfGuests fields from the Reservations table, as we need to support multiple rooms per reservation, and the number of guests will be detailed in the linked table. Add fields to manage the overall status and total cost of the reservation, accommodating multiple rooms.
-- Identify and Drop the Foreign Key Constraint:
SELECT 
    CONSTRAINT_NAME 
FROM 
    INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE 
    TABLE_NAME = 'Reservations' 
    AND CONSTRAINT_TYPE = 'FOREIGN KEY';

	ALTER TABLE Reservations
DROP CONSTRAINT FK__Reservati__RoomI__5070F446;

-- Drop the RoomID and NumberOfGuests Column:
ALTER TABLE Reservations
DROP COLUMN RoomID, NumberOfGuests;

--Adding TotalCost and NumberOfNights Columns to the Reservation table
ALTER TABLE Reservations
ADD TotalCost DECIMAL(10,2),
         NumberOfNights INT;


		 -- New Table for Reservation-Rooms linkage
CREATE TABLE ReservationRooms (
    ReservationRoomID INT PRIMARY KEY IDENTITY(1,1),
    ReservationID INT,
    RoomID INT,
    CheckInDate DATE,
    CheckOutDate DATE,
    FOREIGN KEY (ReservationID) REFERENCES Reservations(ReservationID),
    FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID),
    CONSTRAINT CHK_ResRoomDates CHECK (CheckOutDate > CheckInDate)
);
GO


--Linking Guests to Specific Rooms in a Reservation
-- First, if the table already exists, delete it:
IF OBJECT_ID('ReservationGuests', 'U') IS NOT NULL
    DROP TABLE ReservationGuests;
GO

-- Create the ReservationGuests table
CREATE TABLE ReservationGuests (
    ReservationGuestID INT PRIMARY KEY IDENTITY(1,1),
    ReservationRoomID INT,  -- Linking directly to the ReservationRooms table
    GuestID INT,
    FOREIGN KEY (ReservationRoomID) REFERENCES ReservationRooms(ReservationRoomID),
    FOREIGN KEY (GuestID) REFERENCES Guests(GuestID)
);


--- Modifying the Payments and Removing BatchPayments and Adding Payment Details table
-- Please delete the Existing Refund, PaymentBatches and Payment tables. We are also going to create the tables with different names.
DROP Table Refunds;
DROP TABLE Payments;
DROP TABLE PaymentBatches;

-- Create the Payment table with the following structure.
CREATE TABLE Payments (
    PaymentID INT PRIMARY KEY IDENTITY(1,1),
    ReservationID INT,
    Amount DECIMAL(10,2),
    GST DECIMAL(10,2),
    TotalAmount DECIMAL(10,2),
    PaymentDate DATETIME DEFAULT GETDATE(),
    PaymentMethod NVARCHAR(50),
    PaymentStatus NVARCHAR(50) DEFAULT 'Pending' CHECK (PaymentStatus IN ('Pending', 'Completed', 'Failed', 'Refunded')),
    FailureReason NVARCHAR(MAX),
    FOREIGN KEY (ReservationID) REFERENCES Reservations(ReservationID)
);
GO

-- Create the PaymentDetails table with the following structure. 
CREATE TABLE PaymentDetails (
    PaymentDetailID INT PRIMARY KEY IDENTITY(1,1),
    PaymentID INT,
    ReservationRoomID INT,
    Amount DECIMAL(10,2), -- Base Amount
    NumberOfNights INT, 
    GST DECIMAL(10,2), -- GST Based on the Base Amount
    TotalAmount DECIMAL(10,2), -- (Amount * NumberOfNights) + GST
    FOREIGN KEY (PaymentID) REFERENCES Payments(PaymentID),
    FOREIGN KEY (ReservationRoomID) REFERENCES ReservationRooms(ReservationRoomID)
);
GO

-- Table for tracking Refunds. We are not changing this table
CREATE TABLE Refunds (
    RefundID INT PRIMARY KEY IDENTITY(1,1),
    PaymentID INT,
    RefundAmount DECIMAL(10,2),
    RefundDate DATETIME DEFAULT GETDATE(),
    RefundReason NVARCHAR(255),
    RefundMethodID INT,
    ProcessedByUserID INT,
    RefundStatus NVARCHAR(50),
    FOREIGN KEY (PaymentID) REFERENCES Payments(PaymentID),
    FOREIGN KEY (RefundMethodID) REFERENCES RefundMethods(MethodID),
    FOREIGN KEY (ProcessedByUserID) REFERENCES Users(UserID)
);
GO


--Modifying spSearchByAvailability Stored Procedure:


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

    -- Select rooms that are not currently booked for the given date range and not under maintenance
    SELECT r.RoomID, r.RoomNumber, r.RoomTypeID, r.Price, r.BedType, r.ViewType, r.Status,
           rt.TypeName, rt.AccessibilityFeatures, rt.Description
    FROM Rooms r
    JOIN RoomTypes rt ON r.RoomTypeID = rt.RoomTypeID
    LEFT JOIN ReservationRooms rr ON rr.RoomID = r.RoomID
    LEFT JOIN Reservations res ON rr.ReservationID = res.ReservationID 
        AND res.Status NOT IN ('Cancelled')
        AND (
            (res.CheckInDate <= @CheckOutDate AND res.CheckOutDate >= @CheckInDate)
        )
    WHERE res.ReservationID IS NULL AND r.Status = 'Available' AND r.IsActive = 1
END;
GO


--Create a User-Defined Table Type
-- First, we need to create a user-defined table type that can be used as a parameter for our stored procedure. This will take multiple Room IDs 
CREATE TYPE RoomIDTableType AS TABLE (RoomID INT);
GO


-- This stored procedure will calculate and return the Total Cost and Room wise Cost Breakup
CREATE OR ALTER PROCEDURE spCalculateRoomCosts
    @RoomIDs RoomIDTableType READONLY,
    @CheckInDate DATE,
    @CheckOutDate DATE,
    @Amount DECIMAL(10, 2) OUTPUT,        -- Base total cost before tax
    @GST DECIMAL(10, 2) OUTPUT,           -- GST amount based on 18%
    @TotalAmount DECIMAL(10, 2) OUTPUT    -- Total cost including GST
AS
BEGIN
    SET NOCOUNT ON;

    -- Calculate the number of nights based on CheckInDate and CheckOutDate
    DECLARE @NumberOfNights INT = DATEDIFF(DAY, @CheckInDate, @CheckOutDate);
    
    IF @NumberOfNights <= 0
    BEGIN
        SET @Amount = 0;
        SET @GST = 0;
        SET @TotalAmount = 0;
        RETURN; -- Exit if the number of nights is zero or negative, which shouldn't happen
    END

    -- Select Individual Rooms Price details
    SELECT 
        r.RoomID,
        r.RoomNumber,
        r.Price AS RoomPrice,
        @NumberOfNights AS NumberOfNights,
        r.Price * @NumberOfNights AS TotalPrice
    FROM 
        Rooms r
    INNER JOIN 
        @RoomIDs ri ON r.RoomID = ri.RoomID;

    -- Calculate total cost (base amount) from the rooms identified by RoomIDs multiplied by NumberOfNights
    SELECT @Amount = SUM(Price * @NumberOfNights) FROM Rooms
    WHERE RoomID IN (SELECT RoomID FROM @RoomIDs);

    -- Calculate GST as 18% of the Amount
    SET @GST = @Amount * 0.18;

    -- Calculate Total Amount as Amount plus GST
    SET @TotalAmount = @Amount + @GST;
END;
GO

-- Stored Procedure for Creating a New Reservation
-- This stored procedure will ensure that both the user exists and the selected rooms are available before creating a reservation
CREATE OR ALTER PROCEDURE spCreateReservation
    @UserID INT,
    @RoomIDs RoomIDTableType READONLY, -- Using the table-valued parameter
    @CheckInDate DATE,
    @CheckOutDate DATE,
    @CreatedBy NVARCHAR(100),
    @Message NVARCHAR(255) OUTPUT,
    @Status BIT OUTPUT,
    @ReservationID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Automatically roll-back the transaction on error.

    BEGIN TRY
        BEGIN TRANSACTION

            -- Check if the user exists
            IF NOT EXISTS (SELECT 1 FROM Users WHERE UserID = @UserID AND IsActive = 1)
            BEGIN
                SET @Message = 'User does not exist or inactive.';
                SET @Status = 0; -- 0 means Failed
                RETURN;
            END

            -- Check if all rooms are available
            IF EXISTS (SELECT 1 FROM Rooms WHERE RoomID IN (SELECT RoomID FROM @RoomIDs) AND Status <> 'Available')
            BEGIN
                SET @Message = 'One or more rooms are not available.';
                SET @Status = 0; -- 0 means Failed
                RETURN;
            END

            -- Calculate the number of nights between CheckInDate and CheckOutDate
            DECLARE @NumberOfNights INT = DATEDIFF(DAY, @CheckInDate, @CheckOutDate);
            IF @NumberOfNights <= 0
            BEGIN
                SET @Message = 'Check-out date must be later than check-in date.';
                SET @Status = 0; -- 0 means Failed
                RETURN;
            END

            -- Calculate the base cost of the rooms for the number of nights and add GST
            DECLARE @BaseCost DECIMAL(10, 2);
            SELECT @BaseCost = SUM(Price * @NumberOfNights) FROM Rooms
            WHERE RoomID IN (SELECT RoomID FROM @RoomIDs);

            -- Calculate Total Amount including 18% GST
            DECLARE @TotalAmount DECIMAL(10, 2) = @BaseCost * 1.18;

            -- Create the Reservation
            INSERT INTO Reservations (UserID, BookingDate, CheckInDate, CheckOutDate, NumberOfNights, TotalCost, Status, CreatedBy, CreatedDate)
            VALUES (@UserID, GETDATE(), @CheckInDate, @CheckOutDate, @NumberOfNights, @TotalAmount, 'Reserved', @CreatedBy, GETDATE());

            SET @ReservationID = SCOPE_IDENTITY();

            -- Assign rooms to the reservation and update room status
            INSERT INTO ReservationRooms (ReservationID, RoomID, CheckInDate, CheckOutDate)
            SELECT @ReservationID, RoomID, @CheckInDate, @CheckOutDate FROM @RoomIDs;

            -- Update the status of the rooms to 'Occupied'
            UPDATE Rooms
            SET Status = 'Occupied'
            WHERE RoomID IN (SELECT RoomID FROM @RoomIDs);

            SET @Message = 'Reservation created successfully.';
            SET @Status = 1; -- 1 means Success
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @Message = ERROR_MESSAGE();
        SET @Status = 0; -- 0 means Failed
    END CATCH
END;
GO


-- Designing the GuestDetailsTableType
CREATE TYPE GuestDetailsTableType AS TABLE (
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    Phone NVARCHAR(15),
    AgeGroup NVARCHAR(50),
    Address NVARCHAR(500),
    CountryId INT,
    StateId INT,
    RoomID INT -- This will link the guest to a specific room in a reservation
);
GO


-----Create the Stored Procedure for Adding Guests
CREATE OR ALTER PROCEDURE spAddGuestsToReservation
    @UserID INT,
    @ReservationID INT,
    @GuestDetails GuestDetailsTableType READONLY,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Automatically roll-back the transaction on error.

    BEGIN TRY
        BEGIN TRANSACTION
            -- Validate the existence of the user
            IF NOT EXISTS (SELECT 1 FROM Users WHERE UserID = @UserID AND IsActive = 1)
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'User does not exist or inactive.';
                RETURN;
            END

            -- Validate that all RoomIDs are part of the reservation
            IF EXISTS (
                SELECT 1 FROM @GuestDetails gd
                WHERE NOT EXISTS (
                    SELECT 1 FROM ReservationRooms rr
                    WHERE rr.ReservationID = @ReservationID AND rr.RoomID = gd.RoomID
                )
            )
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'One or more RoomIDs are not valid for this reservation.';
                RETURN;
            END

            -- Create a temporary table to store Guest IDs with ReservationRoomID
            CREATE TABLE #TempGuests
            (
                TempID INT IDENTITY(1,1),
                GuestID INT,
                ReservationRoomID INT
            );

            -- Insert guests into Guests table and retrieve IDs
            INSERT INTO Guests (UserID, FirstName, LastName, Email, Phone, AgeGroup, Address, CountryID, StateID, CreatedBy, CreatedDate)
            SELECT @UserID, gd.FirstName, gd.LastName, gd.Email, gd.Phone, gd.AgeGroup, gd.Address, gd.CountryId, gd.StateId, @UserID, GETDATE()
            FROM @GuestDetails gd;

            -- Capture the Guest IDs and the corresponding ReservationRoomID
            INSERT INTO #TempGuests (GuestID, ReservationRoomID)
            SELECT SCOPE_IDENTITY(), rr.ReservationRoomID
            FROM @GuestDetails gd
            JOIN ReservationRooms rr ON gd.RoomID = rr.RoomID AND rr.ReservationID = @ReservationID;

            -- Link each new guest to a room in the reservation
            INSERT INTO ReservationGuests (ReservationRoomID, GuestID)
            SELECT ReservationRoomID, GuestID
            FROM #TempGuests;

            SET @Status = 1; -- Success
            SET @Message = 'All guests added successfully.';
            COMMIT TRANSACTION;

            -- Cleanup the temporary table
            DROP TABLE #TempGuests;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();

        -- Cleanup the temporary table in case of failure
        IF OBJECT_ID('tempdb..#TempGuests') IS NOT NULL
            DROP TABLE #TempGuests;
    END CATCH
END;
GO


-- Stored Procedure for Processing the Payment
CREATE OR ALTER PROCEDURE spProcessPayment
    @ReservationID INT,
    @TotalAmount DECIMAL(10,2),
    @PaymentMethod NVARCHAR(50),
    @PaymentID INT OUTPUT,
    @Status BIT OUTPUT,
    @Message NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensures that if an error occurs, all changes are rolled back

    BEGIN TRY
        BEGIN TRANSACTION

            -- Validate that the reservation exists and the total cost matches
            DECLARE @TotalCost DECIMAL(10,2);
            DECLARE @NumberOfNights INT;
            SELECT @TotalCost = TotalCost, @NumberOfNights = NumberOfNights
            FROM Reservations 
            WHERE ReservationID = @ReservationID;
            
            IF @TotalCost IS NULL
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Reservation does not exist.';
                RETURN;
            END

            IF @TotalAmount <> @TotalCost
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Input total amount does not match the reservation total cost.';
                RETURN;
            END

            -- Calculate Base Amount and GST, assuming GST as 18% for the Payments table
            DECLARE @BaseAmount DECIMAL(10,2) = @TotalCost / 1.18; 
            DECLARE @GST DECIMAL(10,2) = @TotalCost - @BaseAmount;

            -- Insert into Payments Table
            INSERT INTO Payments (ReservationID, Amount, GST, TotalAmount, PaymentDate, PaymentMethod, PaymentStatus)
            VALUES (@ReservationID, @BaseAmount, @GST, @TotalCost, GETDATE(), @PaymentMethod, 'Pending');

            SET @PaymentID = SCOPE_IDENTITY(); -- Capture the new Payment ID

            -- Insert into PaymentDetails table for each room with number of nights and calculated amounts
            INSERT INTO PaymentDetails (PaymentID, ReservationRoomID, Amount, NumberOfNights, GST, TotalAmount)
            SELECT @PaymentID, rr.ReservationRoomID, r.Price, @NumberOfNights, (r.Price * @NumberOfNights) * 0.18, r.Price * @NumberOfNights + (r.Price * @NumberOfNights) * 0.18
            FROM ReservationRooms rr
            JOIN Rooms r ON rr.RoomID = r.RoomID
            WHERE rr.ReservationID = @ReservationID;

            SET @Status = 1; -- Success
            SET @Message = 'Payment Processed Successfully.';
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH
END;
GO





-- Stored Procedure for Updating the Payment Status
CREATE OR ALTER PROCEDURE spUpdatePaymentStatus
    @PaymentID INT,
    @NewStatus NVARCHAR(50), -- 'Completed' or 'Failed'
    @FailureReason NVARCHAR(255) = NULL, -- Optional reason for failure
    @Status BIT OUTPUT, -- Output to indicate success/failure of the procedure
    @Message NVARCHAR(255) OUTPUT -- Output message detailing the result
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensure that if an error occurs, all changes are rolled back

    BEGIN TRY
        BEGIN TRANSACTION
            -- Check if the payment exists and is in a 'Pending' status
            DECLARE @CurrentStatus NVARCHAR(50);
            SELECT @CurrentStatus = PaymentStatus FROM Payments WHERE PaymentID = @PaymentID;
            
            IF @CurrentStatus IS NULL
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Payment record does not exist.';
                RETURN;
            END

            IF @CurrentStatus <> 'Pending'
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Payment status is not Pending. Cannot update.';
                RETURN;
            END

            -- Validate the new status
            IF @NewStatus NOT IN ('Completed', 'Failed')
            BEGIN
                SET @Status = 0; -- Failure
                SET @Message = 'Invalid status value. Only "Completed" or "Failed" are acceptable.';
                RETURN;
            END

            -- Update the Payment Status
            UPDATE Payments
            SET PaymentStatus = @NewStatus,
                FailureReason = CASE WHEN @NewStatus = 'Failed' THEN @FailureReason ELSE NULL END
            WHERE PaymentID = @PaymentID;

            -- If Payment Fails, update corresponding reservation and room statuses
            IF @NewStatus = 'Failed'
            BEGIN
                DECLARE @ReservationID INT;
                SELECT @ReservationID = ReservationID FROM Payments WHERE PaymentID = @PaymentID;

                -- Update Reservation Status
                UPDATE Reservations
                SET Status = 'Cancelled'
                WHERE ReservationID = @ReservationID;

                -- Update Room Status
                UPDATE Rooms
                SET Status = 'Available'
                FROM Rooms
                JOIN ReservationRooms ON Rooms.RoomID = ReservationRooms.RoomID
                WHERE ReservationRooms.ReservationID = @ReservationID;
            END

            SET @Status = 1; -- Success
            SET @Message = 'Payment Status Updated Successfully.';
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @Status = 0; -- Failure
        SET @Message = ERROR_MESSAGE();
    END CATCH
END;
GO

