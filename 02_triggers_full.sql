

-- 5. CÁC TRIGGER BỔ SUNG

-------------------------------------------------------

-- ===================== TRG01: Kiểm tra tồn kho trước khi bán =====================

-- Nếu số lượng mua > tồn kho => ROLLBACK và báo lỗi

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

  -- Nếu hợp lệ, thực hiện INSERT thật (không specify MA_CTHD để cho IDENTITY tự tạo)
  INSERT INTO CTHD (SO_LUONG, GIA, MA_HD, MA_HH)
  SELECT SO_LUONG, GIA, MA_HD, MA_HH FROM inserted;
END;

GO

-- ===================== TRG02: Trừ tồn kho khi bán hàng =====================

-- Sau khi insert CTHD thành công => giảm SO_LUONG trong HANG_HOA

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

-- ===================== TRG03: Cộng tồn kho khi nhập hàng =====================

-- Sau khi insert HANG_NHAP => tăng SO_LUONG trong HANG_HOA

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

-- ===================== TRG04: Trừ tồn kho khi bỏ hàng =====================

-- Sau khi insert BO_HANG => giảm SO_LUONG trong HANG_HOA

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

-- ===================== TRG05: Cập nhật điểm khách hàng sau khi bán =====================

-- Quy tắc: Cứ mỗi 100.000 đ tổng hóa đơn => +1 điểm
-- Kích hoạt sau khi INSERT hóa đơn mới (không phải UPDATE)

CREATE TRIGGER trg_CapNhatDiemKhachHang
ON HOA_DON
AFTER INSERT
AS
BEGIN
  UPDATE KH
  SET KH.DIEM = KH.DIEM + FLOOR(I.TONG_TIEN / 100000)
  FROM KHACH_HANG KH
  INNER JOIN inserted I ON KH.ID_KH = I.ID_KH
  WHERE I.ID_KH IS NOT NULL;
END;

GO

-- ===================== TRG06: Tự động nâng hạng khách hàng theo tổng chi tiêu =====================

-- Quy tắc (từ đề tài):
-- Thân thiết: < 50.000.000 VNĐ (điểm < 500)
-- Bạc: 50.000.000 - 149.999.999 VNĐ (điểm 500-1499)
-- Vàng: 150.000.000 - 499.999.999 VNĐ (điểm 1500-4999)
-- Kim cương: >= 500.000.000 VNĐ (điểm >= 5000)

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

-- ===================== TRG07: Cập nhật số ca làm khi chấm công =====================

-- Mỗi khi INSERT vào CHAM_CONG => +1 SO_CA_LAM trong bảng LUONG

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

-- ===================== TRG08: Ngăn xóa hàng hóa đã có trong hóa đơn =====================

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

  -- Nếu chưa bán => cho phép xóa
  DELETE FROM HANG_HOA
  WHERE MA_HH IN (SELECT MA_HH FROM deleted);
END;

GO
