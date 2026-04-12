-- 4. CÁC TRUY VẤN MẪU
---------------------------------------------------------

-- Q01: Xem bảng quy tắc xếp hạng khách hàng
SELECT HANG, DIEM_MIN, DIEM_MAX, MO_TA FROM HANG_KH ORDER BY DIEM_MIN;
GO

-- Q02: Danh sách khách hàng kèm hạng, điểm, điểm còn thiếu để lên hạng
SELECT
    CN.TEN,
    KH.KHTT                   AS HANG_HIEN_TAI,
    KH.DIEM,
    CASE
        WHEN KH.KHTT = N'Kim cương' THEN N'Đã đạt hạng cao nhất'
        ELSE CAST(HK.DIEM_MAX - KH.DIEM + 1 AS NVARCHAR) + N' điểm nữa để lên hạng'
    END                        AS TRANG_THAI_DIEM
FROM KHACH_HANG KH
INNER JOIN CON_NGUOI CN ON KH.ID_KH = CN.ID_CN
INNER JOIN HANG_KH   HK ON KH.KHTT  = HK.HANG
ORDER BY KH.DIEM DESC;
GO

-- Q03: Bảng lương nhân viên
-- LUONG_THUC_NHAN = LUONG_CO_BAN (mỗi ca) x SO_CA_LAM + THUONG
SELECT
    CN.TEN                                                    AS HO_TEN,
    CV.TEN_CV                                                 AS CHUC_VU,
    FORMAT(CV.LUONG_CO_BAN, 'N0', 'vi-VN') + N'đ/ca'         AS LUONG_MOI_CA,
    L.SO_CA_LAM,
    FORMAT(L.THUONG, 'N0', 'vi-VN') + N'đ'                   AS THUONG,
    FORMAT(CV.LUONG_CO_BAN * L.SO_CA_LAM + L.THUONG,
           'N0', 'vi-VN') + N'đ'                              AS LUONG_THUC_NHAN
FROM LUONG L
INNER JOIN CON_NGUOI CN ON L.ID_NV = CN.ID_CN
INNER JOIN CHUC_VU   CV ON L.MA_CV = CV.MA_CV
ORDER BY (CV.LUONG_CO_BAN * L.SO_CA_LAM + L.THUONG) DESC;
GO