---------------------------------------------------------
-- 2. TRIGGERS
---------------------------------------------------------

-- TRG01: Tự tính TONG_TIEN khi INSERT/UPDATE CTHD
CREATE TRIGGER trg_CapNhatTongTien
ON CTHD
AFTER INSERT, UPDATE
AS
BEGIN
    UPDATE HOA_DON
    SET TONG_TIEN = (
        SELECT ISNULL(SUM(SO_LUONG * GIA), 0)
        FROM CTHD WHERE MA_HD = HOA_DON.MA_HD
    )
    WHERE MA_HD IN (SELECT DISTINCT MA_HD FROM inserted);
END;
GO

-- TRG02: Kiểm tra tồn kho trước khi bán
CREATE TRIGGER trg_KiemTraTonKho
ON CTHD
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted I
        INNER JOIN HANG_HOA HH ON I.MA_HH = HH.MA_HH
        WHERE I.SO_LUONG > HH.SO_LUONG
    )
    BEGIN
        RAISERROR(N'Lỗi: Số lượng mua vượt quá tồn kho!', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    INSERT INTO CTHD (MA_CTHD, SO_LUONG, GIA, MA_HD, MA_HH)
    SELECT MA_CTHD, SO_LUONG, GIA, MA_HD, MA_HH FROM inserted;
END;
GO

-- TRG03: Trừ tồn kho khi bán hàng
CREATE TRIGGER trg_TruTonKho
ON CTHD
AFTER INSERT
AS
BEGIN
    UPDATE HH
    SET HH.SO_LUONG = HH.SO_LUONG - I.SO_LUONG
    FROM HANG_HOA HH
    INNER JOIN inserted I ON HH.MA_HH = I.MA_HH;
END;
GO

-- TRG04: Cộng tồn kho khi nhập hàng
CREATE TRIGGER trg_CongTonKhoKhiNhap
ON HANG_NHAP
AFTER INSERT
AS
BEGIN
    UPDATE HH
    SET HH.SO_LUONG = HH.SO_LUONG + I.SO_LUONG
    FROM HANG_HOA HH
    INNER JOIN inserted I ON HH.MA_HH = I.MA_HH;
END;
GO

-- TRG05: Trừ tồn kho khi bỏ hàng
CREATE TRIGGER trg_TruTonKhoKhiBo
ON BO_HANG
AFTER INSERT
AS
BEGIN
    UPDATE HH
    SET HH.SO_LUONG = HH.SO_LUONG - I.SO_LUONG
    FROM HANG_HOA HH
    INNER JOIN inserted I ON HH.MA_HH = I.MA_HH;
END;
GO

-- TRG06: Cộng điểm khách hàng khi TONG_TIEN thay đổi
-- Quy tắc: 100.000đ = 1 điểm
CREATE TRIGGER trg_CapNhatDiemKhachHang
ON HOA_DON
AFTER UPDATE
AS
BEGIN
    IF UPDATE(TONG_TIEN)
    BEGIN
        UPDATE KH
        SET KH.DIEM = KH.DIEM + FLOOR((I.TONG_TIEN - ISNULL(D.TONG_TIEN, 0)) / 100000)
        FROM KHACH_HANG KH
        INNER JOIN inserted I ON KH.ID_KH = I.ID_KH
        LEFT  JOIN deleted  D ON D.MA_HD  = I.MA_HD
        WHERE I.TONG_TIEN > ISNULL(D.TONG_TIEN, 0);
    END
END;
GO

-- TRG07: Tự động cập nhật hạng KH khi điểm thay đổi
-- Thân thiết: 0-499 | Bạc: 500-1499 | Vàng: 1500-4999 | Kim cương: 5000+
CREATE TRIGGER trg_CapNhatHangKhachHang
ON KHACH_HANG
AFTER UPDATE
AS
BEGIN
    IF UPDATE(DIEM)
    BEGIN
        UPDATE KH
        SET KH.KHTT = CASE
            WHEN I.DIEM >= 5000 THEN N'Kim cương'
            WHEN I.DIEM >= 1500 THEN N'Vàng'
            WHEN I.DIEM >= 500  THEN N'Bạc'
            ELSE N'Thân thiết'
        END
        FROM KHACH_HANG KH
        INNER JOIN inserted I ON KH.ID_KH = I.ID_KH;
    END
END;
GO

-- TRG08: Cập nhật số ca làm khi chấm công
CREATE TRIGGER trg_CapNhatSoCaLam
ON CHAM_CONG
AFTER INSERT
AS
BEGIN
    UPDATE L
    SET L.SO_CA_LAM = L.SO_CA_LAM + SoCaMoi.TONG
    FROM LUONG L
    INNER JOIN (
        SELECT ID_NV, COUNT(*) AS TONG FROM inserted GROUP BY ID_NV
    ) SoCaMoi ON L.ID_NV = SoCaMoi.ID_NV;
END;
GO

-- TRG09: Ngăn xóa hàng hóa đã có trong hóa đơn
CREATE TRIGGER trg_NganXoaHangDaBan
ON HANG_HOA
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM deleted D
        INNER JOIN CTHD CT ON D.MA_HH = CT.MA_HH
    )
    BEGIN
        RAISERROR(N'Không thể xóa hàng hóa đã có trong hóa đơn!', 16, 1);
        RETURN;
    END
    DELETE FROM HANG_HOA WHERE MA_HH IN (SELECT MA_HH FROM deleted);
END;
GO