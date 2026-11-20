-- VirtualTSZ Precision Farming Extension: in-game help page (ESC > Help > this mod).
-- The page lists, for every crop of the loaded map, the removal of one harvest (N, P2O5, K2O in kg/ha), plus the totals
-- with baled straw and with a forage harvest where they differ. No targets:
-- the maps are relative to the soil type target, so absolute targets mean nothing to the player. The numbers are
-- read from the Precision Farming N map and from our P and K maps when the help screen opens, so they follow the
-- map.xml of any map.
-- The category and the page are declared in modDesc.xml (<helpLines>); only the paragraphs are filled here.

VtszHelp = {}
VtszHelp.MOD_NAME = g_currentModName
VtszHelp.PAGE_ID = "cropRequirements"

local modName = g_currentModName

-- page icon atlas (slice id "vtszHelp.cropReq", used by iconSliceId in modDesc.xml)
if g_overlayManager ~= nil and g_overlayManager.addTextureConfigFile ~= nil then
	g_overlayManager:addTextureConfigFile(g_currentModDirectory .. "help/vtszHelpIcons.xml", "vtszHelp")
end

local function text(key, ...)
	local s = g_i18n:getText(key, modName)
	if select("#", ...) > 0 then
		return string.format(s, ...)
	end
	return s
end

-- page table of this mod in the help line manager (created from modDesc <helpLines>)
local function findPage(pageId)
	local categories = g_helpLineManager ~= nil and g_helpLineManager:getCategories(modName) or nil
	if categories == nil then
		return nil
	end
	local wanted = modName .. "." .. (pageId or VtszHelp.PAGE_ID)
	for _, category in ipairs(categories) do
		for _, page in ipairs(category.pages) do
			if page.id == wanted then
				return page
			end
		end
	end
	return nil
end

-- rounded value per soil type index, "-" where a value is missing
local function joinValues(indices, valueOf)
	local parts = {}
	for i, soilTypeIndex in ipairs(indices) do
		local value = valueOf(soilTypeIndex)
		parts[i] = value ~= nil and string.format("%d", MathUtil.round(value)) or "-"
	end
	return table.concat(parts, " / ")
end

-- all soil type indices of the soil map, sorted
local function soilTypeIndices(soilMap)
	local indices = {}
	for index, _ in pairs(soilMap.soilTypes) do
		table.insert(indices, index)
	end
	table.sort(indices)
	return indices
end

-- crops with an own N requirement (Precision Farming gives all other fruit types the first entry)
local function collectCrops(nitrogenMap)
	local crops = {}
	local first = nitrogenMap.fruitRequirements[1]
	for _, requirement in ipairs(nitrogenMap.fruitRequirements) do
		local fruitType = requirement.fruitType
		local own = requirement == first or requirement.bySoilType ~= first.bySoilType
		if fruitType ~= nil and own and fruitType.allowsSeeding then
			local fillType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(fruitType.index)
			table.insert(crops, { fruitType = fruitType, requirement = requirement, title = fillType ~= nil and fillType.title or fruitType.name })
		end
	end
	table.sort(crops, function(a, b)
		return a.title < b.title
	end)
	return crops
end

local function nitrogenOf(nitrogenMap, requirement, soilTypeIndex)
	for _, settings in ipairs(requirement.bySoilType) do
		if settings.soilTypeIndex == soilTypeIndex then
			return (settings.reduction or 0) * nitrogenMap.amountPerState
		end
	end
	return nil
end

function VtszHelp.buildParagraphs()
	local pf = VtszNutrients ~= nil and VtszNutrients.pf or nil
	local nitrogenMap = pf ~= nil and pf.nitrogenMap or nil
	local soilMap = pf ~= nil and pf.soilMap or nil
	local pMap, kMap = pf ~= nil and pf.vtszPMap or nil, pf ~= nil and pf.vtszKMap or nil
	if nitrogenMap == nil or soilMap == nil or pMap == nil or kMap == nil then
		return nil
	end

	local indices = soilTypeIndices(soilMap)

	local paragraphs = {}
	local function add(title, body)
		table.insert(paragraphs, { title = title, text = body, customEnvironment = modName })
	end
	add(text("vtsz_help_cropReq_introTitle"), text("vtsz_help_cropReq_intro"))
	local omMap = pf.vtszOMMap
	if omMap ~= nil then
		add(text("vtsz_help_om_title"), text("vtsz_help_om", string.format("%.4g", omMap.timeScale or 1)))
	end

	for _, crop in ipairs(collectCrops(nitrogenMap)) do
		local index, requirement = crop.fruitType.index, crop.requirement
		local pRequirement, kRequirement = pMap:getRequirement(index), kMap:getRequirement(index)
		local nitrogen = joinValues({ indices[1] }, function(s)
			return nitrogenOf(nitrogenMap, requirement, s)
		end)
		local pPlain, kPlain = MathUtil.round(pRequirement.removal or 0), MathUtil.round(kRequirement.removal or 0)
		-- same rules as NutrientMap:getHarvestChange: baled straw = removal + removalStraw; forage harvest = max(removal,
		-- forageRemoval) + removalStraw when forageRemoval is set, else the same as baled. N has no variant in the mod.
		local function baledOf(r)
			return MathUtil.round((r.removal or 0) + (r.removalStraw or 0))
		end
		local function forageOf(r)
			if r.forageRemoval ~= nil then
				return MathUtil.round(math.max(r.removal or 0, r.forageRemoval) + (r.removalStraw or 0))
			end
			return baledOf(r)
		end
		local pBaled, kBaled = baledOf(pRequirement), baledOf(kRequirement)
		local pForage, kForage = forageOf(pRequirement), forageOf(kRequirement)
		local lines = { text("vtsz_help_cropReq_removal", nitrogen, pPlain, kPlain) }
		local baledDiffers = pBaled ~= pPlain or kBaled ~= kPlain
		if baledDiffers then
			table.insert(lines, text("vtsz_help_cropReq_baled", nitrogen, pBaled, kBaled))
		end
		-- forage line only when it differs from the line above it (baled, or plain when baled is not shown)
		local pPrev, kPrev = baledDiffers and pBaled or pPlain, baledDiffers and kBaled or kPlain
		if pForage ~= pPrev or kForage ~= kPrev then
			table.insert(lines, text("vtsz_help_cropReq_forage", nitrogen, pForage, kForage))
		end
		add(crop.title, table.concat(lines, "\n"))
	end
	return paragraphs
end

----------------------------------------------------------------------------------------------------
-- Page 2: fertilizer content (per 1000 l of product). The help frame has no table element (a paragraph is a title, a text
-- and an optional image), so there is one paragraph per product with one compact line.
----------------------------------------------------------------------------------------------------

-- display order only (shop products first, then base game); every other fill type with data follows, sorted by title
VtszHelp.FERTILIZER_ORDER = {
	"PETISO27", "KARBAMID46", "MAP11_52", "TSP46", "SSP18", "KALISO60", "PATENTKALI", "NPK15_15_15", "NPK8_24_24", "NITROSOL30", "ELESZTOVINASZ",
	"FERTILIZER", "LIQUIDFERTILIZER", "MANURE", "LIQUIDMANURE", "DIGESTATE", "SOLIDDIGESTATE", "CARBOLIME", "LIME",
}

local function formatAmount(value)
	if value >= 100 then
		return string.format("%d", MathUtil.round(value))
	end
	return string.format("%.3g", value)
end

-- N per 1000 l as Precision Farming spreads it (same call the sprayer rate uses, so liquid manure is handled like PF does)
local function nitrogenPer1000(nitrogenMap, fillTypeIndex)
	local litersPerKgN = nitrogenMap:getFertilizerUsageByNitrogenAmount(1, fillTypeIndex)
	if litersPerKgN ~= nil and litersPerKgN > 0 then
		return 1000 / litersPerKgN
	end
	return 0
end

function VtszHelp.buildFertilizerParagraphs()
	local pf = VtszNutrients ~= nil and VtszNutrients.pf or nil
	local nitrogenMap = pf ~= nil and pf.nitrogenMap or nil
	local pMap, kMap, omMap = pf ~= nil and pf.vtszPMap or nil, pf ~= nil and pf.vtszKMap or nil, pf ~= nil and pf.vtszOMMap or nil
	if nitrogenMap == nil or pMap == nil or kMap == nil then
		return nil
	end
	local pHMap = pf.pHMap
	local limeIndex = FillType.LIME

	-- candidate fill types: N fertilizers of PF plus everything with P, K or OM content in the config
	local candidates = {}
	for _, nAmount in ipairs(nitrogenMap.fertilizerUsage.nAmounts) do
		candidates[nAmount.fillTypeIndex] = true
	end
	for _, map in ipairs({ pMap, kMap, omMap }) do
		for fillTypeIndex in pairs(map.fillTypeContents or {}) do
			candidates[fillTypeIndex] = true
		end
	end
	if pHMap ~= nil and limeIndex ~= nil then
		candidates[limeIndex] = true
	end

	local entries, rank = {}, {}
	for i, name in ipairs(VtszHelp.FERTILIZER_ORDER) do
		rank[name] = i
	end
	for fillTypeIndex in pairs(candidates) do
		local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
		if fillType ~= nil then
			local pValue = pMap.fillTypeContents[fillTypeIndex]
			local kValue = kMap.fillTypeContents[fillTypeIndex]
			local omValue = omMap ~= nil and omMap.fillTypeContents[fillTypeIndex] or nil
			local n = nitrogenPer1000(nitrogenMap, fillTypeIndex)
			local p = pValue ~= nil and pValue.value or 0
			local k = kValue ~= nil and kValue.value or 0
			local om = omValue ~= nil and omValue.value or 0
			local ph = 0
			if pHMap ~= nil and fillTypeIndex == limeIndex and pHMap.limeUsage ~= nil and (pHMap.limeUsage.usagePerState or 0) > 0 then
				ph = (pHMap.pHValuePerState or 0) * 1000 / pHMap.limeUsage.usagePerState
			end
			local parts = {}
			if n > 0 or p > 0 or k > 0 then
				table.insert(parts, text("vtsz_help_fert_npk", formatAmount(n), formatAmount(p), formatAmount(k)))
			end
			if om > 0 then
				table.insert(parts, text("vtsz_help_fert_om", string.format("%.4g", om)))
			end
			if ph > 0 then
				table.insert(parts, text("vtsz_help_fert_ph", string.format("%.2f", ph)))
			end
			if #parts > 0 then
				table.insert(entries, {
					rank = rank[fillType.name] or 1000,
					title = fillType.title or fillType.name,
					text = table.concat(parts, " | "),
				})
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.title < b.title
	end)

	local paragraphs = {}
	local function add(title, body)
		table.insert(paragraphs, { title = title, text = body, customEnvironment = modName })
	end
	add(text("vtsz_help_fert_introTitle"), text("vtsz_help_fert_intro", string.format("%.4g", omMap ~= nil and omMap.timeScale or 1)))
	for _, entry in ipairs(entries) do
		add(entry.title, entry.text)
	end
	return paragraphs
end

VtszHelp.PAGES = {
	{ id = "cropRequirements", build = "buildParagraphs" },
	{ id = "fertilizerContent", build = "buildFertilizerParagraphs" },
}

-- Fills the pages; runs every time the help screen opens (cheap, a few dozen crops and products).
function VtszHelp.refresh()
	for _, def in ipairs(VtszHelp.PAGES) do
		local page = findPage(def.id)
		if page ~= nil then
			local ok, paragraphs = pcall(VtszHelp[def.build])
			if not ok then
				Logging.warning("[VTSZ-NUT] help page %s: %s", def.id, tostring(paragraphs))
			elseif paragraphs ~= nil then
				page.paragraphs = paragraphs
			end
		end
	end
end

InGameMenuHelpFrame.onFrameOpen = Utils.prependedFunction(InGameMenuHelpFrame.onFrameOpen, function()
	VtszHelp.refresh()
end)
