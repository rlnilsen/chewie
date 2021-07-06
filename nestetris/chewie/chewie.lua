local lfs = require('lfs')

local function extract_fields(ramdump, field_positions, type_parsers)
	local t = {}
	for fieldname, field in pairs(field_positions) do
		local data = ramdump:sub(field.start+1, field.start+field.len)
		local parse = type_parsers[field.type]
		t[fieldname] = parse(data)
	end
	return t
end

local function load_ramdump(filepath)
	local f = assert(io.open(filepath, 'rb'))
	local data = assert(f:read('a'))
	f:close()
	return data
end

local function find_ramdump_files(dirpath, field_positions, callback)
	local filepaths = {}
	for filename in lfs.dir(dirpath) do
		if filename:find'%.ram$' then
			local filepath = dirpath .. filename
			if assert(lfs.attributes(filepath, 'mode')) == 'file' then
				filepaths[#filepaths+1] = filepath
			end
		end
	end
	return filepaths
end

local function parse_ramdump_filepath(filepath)
	local t, gamestate = {}
	t.year, t.month, t.day, t.hour, t.min, t.sec, gamestate = filepath:match('(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)(%d%d)%-(.-)%.ram$')
	return os.time(t), gamestate
end

local FIELDPOSITIONS = {
	currentlevel = { start=0x0064, len=1, type='unsigned' },
	startlevel   = { start=0x0067, len=1, type='unsigned' },
	score        = { start=0x0073, len=3, type='bcd' },
	lines        = { start=0x0070, len=2, type='bcd' },
	singles      = { start=0x00D8, len=1, type='bcd' },
	doubles      = { start=0x00D9, len=1, type='bcd' },
	triples      = { start=0x00DA, len=1, type='bcd' },
	tetrises     = { start=0x00DB, len=1, type='bcd' },
	pieces       = { start=0x03E0, len=2, type='bcd' },
	stat1        = { start=0x03E2, len=2, type='bcd' },
	stat2        = { start=0x03E4, len=2, type='bcd' },
	stat3        = { start=0x03E6, len=2, type='bcd' },
	stat4        = { start=0x03E8, len=2, type='bcd' },
	stat5        = { start=0x03EA, len=2, type='bcd' },
	stat6        = { start=0x03EC, len=2, type='bcd' },
	statT        = { start=0x03F0, len=2, type='bcd' },
	statJ        = { start=0x03F2, len=2, type='bcd' },
	statZ        = { start=0x03F4, len=2, type='bcd' },
	statO        = { start=0x03F6, len=2, type='bcd' },
	statS        = { start=0x03F8, len=2, type='bcd' },
	statL        = { start=0x03FA, len=2, type='bcd' },
	statI        = { start=0x03FC, len=2, type='bcd' },
}

local FIELDSEPARATOR = '\t'
local DATETIMEFORMAT = '%Y-%m-%d %H:%M:%S'

local function parse_unsigned(data)
	assert(#data == 1)
	return string.byte(data)
end

local function bcd_to_number(byte)
	assert(#byte == 1)
	byte = string.byte(byte)
	local lo = byte      & 0x0f
	local hi = byte >> 4 & 0x0f
	return 10*hi + lo
end

local function parse_bcd(data)
	assert(#data > 0)
	local v = 0
	for i=1, #data do
		local n = bcd_to_number(data:sub(i, i))
		v = v + 100^(i-1) * n
	end
	return v
end

local TYPEPARSERS = {
	unsigned = parse_unsigned,
	bcd = parse_bcd,
}

local function process_ramdump_files(ramdumpdirpath, outputfilepath)
	-- 
	local filepaths = find_ramdump_files(ramdumpdirpath)
	table.sort(filepaths)
	
	if #filepaths == 0 then
		print(("No RAM dump files found in '%s'"):format(ramdumpdirpath))
		return
	end

	local outputfile = assert(io.open(outputfilepath, 'w'))

	-- write field headers
	assert(outputfile:write('starttime',  FIELDSEPARATOR))
	assert(outputfile:write('endtime',    FIELDSEPARATOR))
	assert(outputfile:write('startlevel', FIELDSEPARATOR))
	assert(outputfile:write('endlevel',   FIELDSEPARATOR))
	assert(outputfile:write('score',      FIELDSEPARATOR))
	assert(outputfile:write('lines',      FIELDSEPARATOR))
	assert(outputfile:write('statT',      FIELDSEPARATOR))
	assert(outputfile:write('statJ',      FIELDSEPARATOR))
	assert(outputfile:write('statZ',      FIELDSEPARATOR))
	assert(outputfile:write('statO',      FIELDSEPARATOR))
	assert(outputfile:write('statS',      FIELDSEPARATOR))
	assert(outputfile:write('statL',      FIELDSEPARATOR))
	assert(outputfile:write('statI',      FIELDSEPARATOR))
	assert(outputfile:write('singles',    FIELDSEPARATOR))
	assert(outputfile:write('doubles',    FIELDSEPARATOR))
	assert(outputfile:write('triples',    FIELDSEPARATOR))
	assert(outputfile:write('tetrises',   FIELDSEPARATOR))
	assert(outputfile:write('pieces',     FIELDSEPARATOR))
	assert(outputfile:write('stat1',      FIELDSEPARATOR))
	assert(outputfile:write('stat2',      FIELDSEPARATOR))
	assert(outputfile:write('stat3',      FIELDSEPARATOR))
	assert(outputfile:write('stat4',      FIELDSEPARATOR))
	assert(outputfile:write('stat5',      FIELDSEPARATOR))
	assert(outputfile:write('stat6',      FIELDSEPARATOR))
	assert(outputfile:write('\n'))
	
	-- iterate found ramdump files in alphabetical order
	local prevfileinfo = {}
	for _, filepath in ipairs(filepaths) do
		print("Processing:", filepath)

		local time, gamestate = parse_ramdump_filepath(filepath)
		local ramdump = load_ramdump(filepath)
		local field_values = extract_fields(ramdump, FIELDPOSITIONS, TYPEPARSERS)

		if gamestate == 'end' then
			if prevfileinfo.gamestate ~= 'begin' then
				error(("Missing '-begin.ram' file for '%s'"):format(filepath))
			end
		
			-- write field values
			assert(outputfile:write(os.date(DATETIMEFORMAT, prevfileinfo.time), FIELDSEPARATOR))
			assert(outputfile:write(os.date(DATETIMEFORMAT, time),              FIELDSEPARATOR))
			assert(outputfile:write(field_values.startlevel,                    FIELDSEPARATOR))
			assert(outputfile:write(field_values.currentlevel,                  FIELDSEPARATOR))
			assert(outputfile:write(field_values.score,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.lines,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statT,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statJ,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statZ,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statO,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statS,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statL,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statI,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.singles,                       FIELDSEPARATOR))
			assert(outputfile:write(field_values.doubles,                       FIELDSEPARATOR))
			assert(outputfile:write(field_values.triples,                       FIELDSEPARATOR))
			assert(outputfile:write(field_values.tetrises,                      FIELDSEPARATOR))
			assert(outputfile:write(field_values.pieces,                        FIELDSEPARATOR))
			assert(outputfile:write(field_values.stat1,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.stat2,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.stat3,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.stat4,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.stat5,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.stat6,                         FIELDSEPARATOR))
			assert(outputfile:write('\n'))
		end

		prevfileinfo.time = time
		prevfileinfo.gamestate = gamestate
		prevfileinfo.field_values = field_values
	end
	
	outputfile:close()

	-- move all processed files to subdirectory
	local DIRSEP = package.config:sub(1,1)
	for _, filepath in ipairs(filepaths) do
		local dest = filepath:gsub('^(.*)('..DIRSEP..')(.-)$', '%1'..DIRSEP..'processed'..DIRSEP..'%3')
		assert(os.rename(filepath, dest))
		print("Moved file:", filepath, dest)
	end
end

--process_ramdump_files([[\\fileserver\upload\nestetris\]], os.date('%Y%m%d-%H%M%S')..'.txt')
--process_ramdump_files([[.\]], [[\\fileserver\upload\nestetris\]]..os.date('%Y%m%d-%H%M%S')..'.txt')
--print(parse_bcd(string.char(0x56, 0x34, 0x12)))
--do return end

local ramdumpdirpath, outputfilepath = ...
outputfilepath = os.date(outputfilepath)
process_ramdump_files(ramdumpdirpath, outputfilepath)

print("\nAll RAM dump files processed without error")
