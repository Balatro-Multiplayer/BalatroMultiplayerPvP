function PVP.UTILS.bxor(a, b)
	local res = 0
	local bitval = 1
	while a > 0 and b > 0 do
		local a_bit = a % 2
		local b_bit = b % 2
		if a_bit ~= b_bit then res = res + bitval end
		bitval = bitval * 2
		a = math.floor(a / 2)
		b = math.floor(b / 2)
	end
	res = res + (a + b) * bitval
	return res
end

function PVP.UTILS.encrypt_string(str)
	local hash = 2166136261
	for i = 1, #str do
		hash = PVP.UTILS.bxor(hash, str:byte(i))
		hash = (hash * 16777619) % 2 ^ 32
	end
	return string.format("%08x", hash)
end

-- Hand evaluator.
function PVP.UTILS.joker_hash(str)
	local a, b = 1, 0
	for i = 1, #str do
		a = (a + str:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return string.format("%08x", b * 65536 + a)
end

function PVP.UTILS.server_connection_ID()
	local os_name = love.system.getOS()
	local raw_id

	if os_name == "Windows" then
		local ffi = require("ffi")

		ffi.cdef([[
		typedef unsigned long DWORD;
		typedef int BOOL;
		typedef const char* LPCSTR;

		BOOL GetVolumeInformationA(
			LPCSTR lpRootPathName,
			char* lpVolumeNameBuffer,
			DWORD nVolumeNameSize,
			DWORD* lpVolumeSerialNumber,
			DWORD* lpMaximumComponentLength,
			DWORD* lpFileSystemFlags,
			char* lpFileSystemNameBuffer,
			DWORD nFileSystemNameSize
		);
		]])

		local serial_ptr = ffi.new("DWORD[1]")
		local ok = ffi.C.GetVolumeInformationA("C:\\", nil, 0, serial_ptr, nil, nil, nil, 0)
		if ok ~= 0 then raw_id = tostring(serial_ptr[0]) end
	elseif os_name == "OS X" then
		local cmd =
			[[ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/ { split($0, line, "\""); printf("%s\n", line[4]); }']]
		local handle = io.popen(cmd)
		local result = handle:read("*a")
		if handle then handle:close() end
		print(result)
		raw_id = tostring(result)
	end

	if not raw_id then raw_id = os.getenv("USER") or os.getenv("USERNAME") or os_name end

	return PVP.UTILS.encrypt_string(raw_id)
end
