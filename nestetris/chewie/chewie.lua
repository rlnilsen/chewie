local lfs = require('lfs')

local function generate_tetristoascii_lut()
	local s = '01234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ-,\'>!'
	local t = {}
	for i=1,#s do
		t[string.char(i-1)] = s:sub(i, i)
	end
	t[string.char(255)] = ' '
	return t
end

local function extract_fields(nametable, field_positions, charlut)
	local t = {}
	for fieldname, fieldpos in pairs(field_positions) do
		local data = nametable:sub(fieldpos.start+1, fieldpos.start+fieldpos.len)
		t[fieldname] = data:gsub('.', charlut)
	end
	return t
end

local function load_nametable(filepath)
	local f = assert(io.open(filepath, 'rb'))
	local data = assert(f:read('a'))
	f:close()
	return data
end

local function find_nametable_files(dirpath, field_positions, callback)
	local filepaths = {}
	for filename in lfs.dir(dirpath) do
		if filename:find'%.nam$' then
			local filepath = dirpath .. filename
			if assert(lfs.attributes(filepath, 'mode')) == 'file' then
				filepaths[#filepaths+1] = filepath
			end
		end
	end
	return filepaths
end

local function parse_nametable_filepath(filepath)
	local t, gamestate = {}
	t.year, t.month, t.day, t.hour, t.min, t.sec, gamestate = filepath:match('(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)(%d%d)%-(.-)%.nam$')
	return os.time(t), gamestate
end

local FIELDPOSITIONS = {
	score = { start=0x118, len=6 },
	lines = { start=0x073, len=3 },
	level = { start=0x2ba, len=2 },
	statT = { start=0x186, len=3 },
	statJ = { start=0x1c6, len=3 },
	statZ = { start=0x206, len=3 },
	statO = { start=0x246, len=3 },
	statS = { start=0x286, len=3 },
	statL = { start=0x2c6, len=3 },
	statI = { start=0x306, len=3 },
}

local TETRISTOASCII = generate_tetristoascii_lut()
local FIELDSEPARATOR = '\t'
local DATETIMEFORMAT = '%Y-%m-%d %H:%M:%S'

local function process_nametable_files(nametabledirpath, outputfilepath)
	-- 
	local filepaths = find_nametable_files(nametabledirpath)
	table.sort(filepaths)
	
	if #filepaths == 0 then
		print(("No nametable files found in '%s'"):format(nametabledirpath))
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
	assert(outputfile:write('\n'))
	
	-- iterate found nametable files in alphabetical order
	local prevfileinfo = {}
	for _, filepath in ipairs(filepaths) do
		print("Processing:", filepath)

		local time, gamestate = parse_nametable_filepath(filepath)
		local nametable = load_nametable(filepath)
		local field_values = extract_fields(nametable, FIELDPOSITIONS, TETRISTOASCII)

		if gamestate == 'end' then
			if prevfileinfo.gamestate ~= 'begin' then
				error(("Missing '-begin.nam' file for '%s'"):format(filepath))
			end
		
			-- write field values
			assert(outputfile:write(os.date(DATETIMEFORMAT, prevfileinfo.time), FIELDSEPARATOR))
			assert(outputfile:write(os.date(DATETIMEFORMAT, time),              FIELDSEPARATOR))
			assert(outputfile:write(prevfileinfo.field_values.level,            FIELDSEPARATOR))
			assert(outputfile:write(field_values.level,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.score,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.lines,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statT,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statJ,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statZ,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statO,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statS,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statL,                         FIELDSEPARATOR))
			assert(outputfile:write(field_values.statI,                         FIELDSEPARATOR))
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

--process_nametable_files([[\\fileserver\upload\nestetris\]], os.date('%Y%m%d-%H%M%S')..'.txt')
--process_nametable_files([[.\]], [[\\fileserver\upload\nestetris\]]..os.date('%Y%m%d-%H%M%S')..'.txt')
--do return end

local nametabledirpath, outputfilepath = ...
outputfilepath = os.date(outputfilepath)
process_nametable_files(nametabledirpath, outputfilepath)

print("\nAll nametable files processed without error")
