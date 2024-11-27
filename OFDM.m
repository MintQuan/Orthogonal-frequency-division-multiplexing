clc; clear; close all;

N = 64;   % T?ng s? ký hi?u
Nd = 48;  % S? ký hi?u d? li?u
Np = 4;   % S? pilot
Nz = 12;  % S? giá tr? không
Nc = N/4; % S? ti?n t? vòng

sigma_n = 0.001; % P c?a AWGN
img = imread('image.png'); % Thay 'image.png' bằng đường dẫn đến ảnh
img_gray = rgb2gray(img); % Chuyển ảnh sang grayscale (nếu là ảnh màu)
img_bin = de2bi(img_gray(:), 8, 'left-msb'); % Chuyển mỗi pixel thành chuỗi nhị phân 8-bit
img_bits = reshape(img_bin', 1, []); % Chuyển về chuỗi bit 1D

%Kích thước ảnh
img_size = size(img_gray);
height_bit = de2bi(img_size(1), 24, 'left-msb');
width_bits = de2bi(img_size(2), 24, 'left-msb');
img_size = [height_bit width_bits];

% Số khung cần thiết để truyền dữ liệu
num_frames = ceil(length(img_bits) / Nd);

% Chia dữ liệu thành nhiều khung
BitData_frames = [img_size mat2cell(img_bits, 1, repmat(Nd, 1, num_frames))] ;
BitDemod_frames = [];

% =========== Kênh ?a ???ng
L = 2;
sigma_h = 1;

% =========== Chu?i hu?n luy?n
PL = 1*ones(1,Np);

% =========== Mô ph?ng BER
for j = 1:length(BitData_frames)
    % KH?I PHÁT
    BitData = BitData_frames{j};
    % ========== ?i?u ch? BPSK
    SymData = zeros(1, Nd);
    index0 = find(BitData == 0);
    SymData(index0) = -1;
    index1 = find(BitData == 1);
    SymData(index1) = 1;

    % =========== Khung d? li?u truy?n
    S = [zeros(1,6)  SymData(1:5)   PL(1) ...
        SymData(6:20)  PL(2) ...
        SymData(21:33) PL(3) ...
        SymData(34:45) PL(4) ...
        SymData(46:48) zeros(1,6)];

    % =========== IFFT
    s_ifft = ifft(S);

    % =========== Chèn CP
    s_cp = [s_ifft(N-Nc+1:N)  s_ifft];


    % KÊNH TRUY?N
    % =========== Kênh ?a ???ng
    h = sqrt(sigma_h/2) * (randn(1,L) + 1i*randn(1,L));

    % KH?I THU
    % =========== Tín hi?u nh?n
    y_temp = conv(s_cp, h);
    n = sqrt(sigma_n/2) * (randn(1,N+Nc+L-1) + 1i*randn(1,N+Nc+L-1));
    y = y_temp + n;

    % =========== Tách CP
    yt_cp = y(Nc+1 : N+Nc);

    % =========== ??c l??ng kênh b?ng LS
    Y = fft(yt_cp);      % fft

    Y_PL = [Y(12) Y(28) Y(42) Y(55)];   % Tách Pilot nh?n
    VT_PL = [12 28 42 55];  % V? trí Pilot
    H_temp = Y_PL ./ PL; % Kênh truy?n t?i Pilot
    H_LS = interp1(VT_PL, H_temp, 1:N, 'spline');   % Kênh ??c l??ng b?ng LS

    hes_LS = ifft(H_LS);
    hes_DFT = hes_LS(1:L);
    H_es = fft(hes_DFT,N);   % Kenh uoc luong DFT


    % =========== Gi?i ?i?u ch?
    T = Y ./ H_es;   % ??c l??ng gi?i ?i?u ch?
    Z = [T(7:11)  T(13:27)  T(29:41)  T(43:54)  T(56:58)];  % Tách d? li?u

    Rez = real(Z);
    BitDemod = zeros(1,Nd);
    index0 = find(Rez < 0);
    BitDemod(index0) = 0;
    index1 = find(Rez >= 0);
    BitDemod(index1) = 1;

    BitDemod_frames = [BitDemod_frames BitDemod] ;
end
% Giải mã chiều cao và chiều rộng
height_received = bi2de(BitDemod_frames(1:24), 'left-msb'); % Lấy 24 bit đầu cho chiều cao
width_received = bi2de(BitDemod_frames(25:48), 'left-msb'); % Tiếp theo 24 bit cho chiều rộng
% Trích xuất chuỗi bit ảnh
image_bits_received = BitDemod_frames(49:end);
% Tái tạo ảnh
num_pixels = height_received * width_received;
image_received = reshape(bi2de(reshape(image_bits_received, 8, num_pixels).', 'left-msb'), width_received, height_received).';
% Hiển thị ảnh tái tạo
imshow(image_received, []);
title('Ảnh tái tạo từ phía thu');