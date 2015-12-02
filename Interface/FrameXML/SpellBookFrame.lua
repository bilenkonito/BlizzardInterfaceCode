MAX_SPELLS = 1024;
MAX_SKILLLINE_TABS = 8;
SPELLS_PER_PAGE = 12;
MAX_SPELL_PAGES = ceil(MAX_SPELLS / SPELLS_PER_PAGE);

BOOKTYPE_SPELL = "spell";
BOOKTYPE_PROFESSION = "professions";
BOOKTYPE_PET = "pet";
BOOKTYPE_CORE_ABILITIES = "core";

local MaxSpellBookTypes = 5;
local SpellBookInfo = {};
SpellBookInfo[BOOKTYPE_SPELL] 		= { 	showFrames = {"SpellBookSpellIconsFrame", "SpellBookSideTabsFrame", "SpellBookPageNavigationFrame"}, 		
											title = SPELLBOOK,
											updateFunc = function() SpellBook_UpdatePlayerTab(); end
										};									
SpellBookInfo[BOOKTYPE_PROFESSION] 	= { 	showFrames = {"SpellBookProfessionFrame"}, 	
											title = TRADE_SKILLS,					
											updateFunc = function() SpellBook_UpdateProfTab(); end,
											bgFileL="Interface\\Spellbook\\Professions-Book-Left",
											bgFileR="Interface\\Spellbook\\Professions-Book-Right"
										};
SpellBookInfo[BOOKTYPE_PET] 		= { 	showFrames = {"SpellBookSpellIconsFrame", "SpellBookPageNavigationFrame"}, 		
											title = PET,
											updateFunc =  function() SpellBook_UpdatePetTab(); end
										};										
SpellBookInfo[BOOKTYPE_CORE_ABILITIES]= { 	showFrames = {"SpellBookCoreAbilitiesFrame", "SpellBookPageNavigationFrame"}, 		
											title = CORE_ABILITIES,
											updateFunc =  function() SpellBook_UpdateCoreAbilitiesTab(); end
										};										
SPELLBOOK_PAGENUMBERS = {};

SpellBookFrames = {	"SpellBookSpellIconsFrame", "SpellBookProfessionFrame",  "SpellBookSideTabsFrame", "SpellBookPageNavigationFrame", "SpellBookCoreAbilitiesFrame"};

PROFESSION_RANKS =  {};
PROFESSION_RANKS[1] = {75,  APPRENTICE};
PROFESSION_RANKS[2] = {150, JOURNEYMAN};
PROFESSION_RANKS[3] = {225, EXPERT};
PROFESSION_RANKS[4] = {300, ARTISAN};
PROFESSION_RANKS[5] = {375, MASTER};
PROFESSION_RANKS[6] = {450, GRAND_MASTER};
PROFESSION_RANKS[7] = {525, ILLUSTRIOUS};
PROFESSION_RANKS[8] = {600, ZEN_MASTER};
PROFESSION_RANKS[9] = {700, DRAENOR_MASTER};
PROFESSION_RANKS[10] = {800, LEGION_MASTER};


OPEN_REASON_PENDING_GLYPH = "pendingglyph";
OPEN_REASON_ACTIVATED_GLYPH = "activatedglyph";

local ceil = ceil;
local strlen = strlen;
local tinsert = tinsert;
local tremove = tremove;

function ToggleSpellBook(bookType)
	HelpPlate_Hide();
	if ( (not HasPetSpells() or not PetHasSpellbook()) and bookType == BOOKTYPE_PET ) then
		return;
	end
	
	local isShown = SpellBookFrame:IsShown();
	if ( isShown and (SpellBookFrame.bookType == bookType) ) then
		HideUIPanel(SpellBookFrame);
		return;
	elseif isShown then
		SpellBookFrame_PlayOpenSound()
		SpellBookFrame.bookType = bookType;	
		SpellBookFrame_Update();
	else	
		SpellBookFrame.bookType = bookType;	
		ShowUIPanel(SpellBookFrame);
	end

	local tutorial, helpPlate = SpellBookFrame_GetTutorialEnum()
	if ( tutorial and not GetCVarBitfield("closedInfoFrames", tutorial) and GetCVarBool("showTutorials") ) then
		if ( helpPlate and not HelpPlate_IsShowing(helpPlate) and SpellBookFrame:IsShown()) then
			HelpPlate_ShowTutorialPrompt( helpPlate, SpellBookFrame.MainHelpButton );
			SetCVarBitfield( "closedInfoFrames", tutorial, true );
		end
	end
end

function SpellBookFrame_GetTutorialEnum()
	local helpPlate;
	local tutorial;
	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		helpPlate = SpellBookFrame_HelpPlate;
		tutorial = LE_FRAME_TUTORIAL_SPELLBOOK;
	elseif ( SpellBookFrame.bookType == BOOKTYPE_PROFESSION ) then
		helpPlate = ProfessionsFrame_HelpPlate;
		tutorial = LE_FRAME_TUTORIAL_PROFESSIONS;
	elseif ( SpellBookFrame.bookType == BOOKTYPE_CORE_ABILITIES ) then
		helpPlate = CoreAbilitiesFrame_HelpPlate;
		tutorial = LE_FRAME_TUTORIAL_CORE_ABILITITES;
	end
	return tutorial, helpPlate;
end

function SpellBookFrame_OnLoad(self)
	self:RegisterEvent("SPELLS_CHANGED");
	self:RegisterEvent("LEARNED_SPELL_IN_TAB");	
	self:RegisterEvent("SKILL_LINES_CHANGED");
	self:RegisterEvent("PLAYER_GUILD_UPDATE");
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	self:RegisterEvent("USE_GLYPH");
	self:RegisterEvent("CANCEL_GLYPH_CAST");
	self:RegisterEvent("ACTIVATE_GLYPH");

	SpellBookFrame.bookType = BOOKTYPE_SPELL;
	-- Init page nums
	SPELLBOOK_PAGENUMBERS[1] = 1;
	SPELLBOOK_PAGENUMBERS[2] = 1;
	SPELLBOOK_PAGENUMBERS[3] = 1;
	SPELLBOOK_PAGENUMBERS[4] = 1;
	SPELLBOOK_PAGENUMBERS[5] = 1;
	SPELLBOOK_PAGENUMBERS[6] = 1;
	SPELLBOOK_PAGENUMBERS[7] = 1;
	SPELLBOOK_PAGENUMBERS[8] = 1;
	SPELLBOOK_PAGENUMBERS[BOOKTYPE_PET] = 1;
	
	-- Set to the class tab by default
	SpellBookFrame.selectedSkillLine = 2;

	-- Initialize tab flashing
	SpellBookFrame.flashTabs = nil;
	
	-- Initialize portrait texture
	SetPortraitToTexture(SpellBookFramePortrait, "Interface\\Spellbook\\Spellbook-Icon");
	
	ButtonFrameTemplate_HideButtonBar(SpellBookFrame);
	ButtonFrameTemplate_HideAttic(SpellBookFrame);
	SpellBookFrameInsetBg:Hide();
end

function SpellBookFrame_OnEvent(self, event, ...)
	if ( event == "SPELLS_CHANGED" ) then
		if ( SpellBookFrame:IsVisible() ) then
			if ( GetNumSpellTabs() < SpellBookFrame.selectedSkillLine ) then
				SpellBookFrame.selectedSkillLine = 2;
			end
			SpellBookFrame_Update();
		end
	elseif ( event == "LEARNED_SPELL_IN_TAB" ) then
		SpellBookFrame_Update();
		local spellID, tabNum, isGuildSpell = ...;
		local flashFrame = _G["SpellBookSkillLineTab"..tabNum.."Flash"];
		if ( SpellBookFrame.bookType == BOOKTYPE_PET or isGuildSpell) then
			return;
		elseif ( tabNum <= GetNumSpellTabs() ) then
			if ( flashFrame ) then
				flashFrame:Show();
				SpellBookFrame.flashTabs = 1;
			end
		end
	elseif (event == "SKILL_LINES_CHANGED") then
		SpellBook_UpdateProfTab();
	elseif (event == "PLAYER_GUILD_UPDATE") then
		-- default to class tab if the selected one is gone - happens if you leave a guild with perks 
		if ( GetNumSpellTabs() < SpellBookFrame.selectedSkillLine ) then
			SpellBookFrame.selectedSkillLine = 2;
			SpellBookFrame_Update();
		else
			SpellBookFrame_UpdateSkillLineTabs();
		end
	elseif ( event == "PLAYER_SPECIALIZATION_CHANGED" ) then
		local unit = ...;
		if ( unit == "player" ) then
			SpellBookFrame.selectedSkillLine = 2; -- number of skilllines will change!
			SpellBookFrame_Update();
		end
	elseif ( event == "USE_GLYPH" ) then
		local slot = ...;
		SpellBookFrame_OpenToPageForSlot(slot, OPEN_REASON_PENDING_GLYPH);
	elseif ( event == "CANCEL_GLYPH_CAST" ) then
		SpellBookFrame_ClearAbilityHighlights();
	elseif ( event == "ACTIVATE_GLYPH" ) then
		local slot = ...;
		SpellBookFrame_OpenToPageForSlot(slot, OPEN_REASON_ACTIVATED_GLYPH);
	end
end

function SpellBookFrame_OnShow(self)
	SpellBookCoreAbilitiesFrame.selectedSpec = GetSpecialization() or 1;
	SpellBookFrame_Update();
	
	-- If there are tabs waiting to flash, then flash them... yeah..
	if ( self.flashTabs ) then
		UIFrameFlash(SpellBookTabFlashFrame, 0.5, 0.5, 30, nil);
	end

	-- Show multibar slots
	MultiActionBar_ShowAllGrids();
	UpdateMicroButtons();

	SpellBookFrame_PlayOpenSound();
	MicroButtonPulseStop(SpellbookMicroButton);
	
	-- if boosted, find the first locked spell and display a tip next to it
	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL and IsCharacterNewlyBoosted() and not GetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_BOOSTED_SPELL_BOOK) ) then
		local spellSlot;
		for i = 1, SPELLS_PER_PAGE do
			local spellBtn = _G["SpellButton" .. i];
			local slotType = select(2,SpellBook_GetSpellBookSlot(spellBtn));
			if (slotType == "FUTURESPELL") then
				if ( not spellSlot or spellBtn:GetID() < spellSlot:GetID() ) then
					spellSlot = spellBtn;
				end
			end
		end
		
		if ( spellSlot ) then
			SpellLockedTooltip:Show();
			SpellLockedTooltip:SetPoint("LEFT", spellSlot, "RIGHT", 16, 0);
		else
			SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_BOOSTED_SPELL_BOOK, true);
		end
	else
		SpellLockedTooltip:Hide();
	end
end

function SpellBookFrame_Update()
	-- Hide all tabs
	SpellBookFrameTabButton3:Hide();
	SpellBookFrameTabButton4:Hide();
	SpellBookFrameTabButton5:Hide();	

	-- Setup tabs	
	-- player spells and professions are always shown
	SpellBookFrameTabButton1:Show();
	SpellBookFrameTabButton1.bookType = BOOKTYPE_SPELL;
	SpellBookFrameTabButton1.binding = "TOGGLESPELLBOOK";
	SpellBookFrameTabButton1:SetText(SpellBookInfo[BOOKTYPE_SPELL].title);
	SpellBookFrameTabButton2:Show();
	SpellBookFrameTabButton2.bookType = BOOKTYPE_PROFESSION;	
	SpellBookFrameTabButton2:SetText(SpellBookInfo[BOOKTYPE_PROFESSION].title);
	SpellBookFrameTabButton2.binding = "TOGGLEPROFESSIONBOOK";
	
	local tabIndex = 3;
	-- check to see if we have a pet
	local hasPetSpells, petToken = HasPetSpells();
	SpellBookFrame.petTitle = nil;
	if ( hasPetSpells and PetHasSpellbook() ) then
		SpellBookFrame.petTitle = _G["PET_TYPE_"..petToken];
		local nextTab = _G["SpellBookFrameTabButton"..tabIndex];
		nextTab:Show();
		nextTab.bookType = BOOKTYPE_PET;		
		nextTab.binding = "TOGGLEPETBOOK";
		nextTab:SetText(SpellBookInfo[BOOKTYPE_PET].title);
		tabIndex = tabIndex+1;
	elseif (SpellBookFrame.bookType == BOOKTYPE_PET) then
		SpellBookFrame.bookType = _G["SpellBookFrameTabButton"..tabIndex-1].bookType;
	end
	
	local level = UnitLevel("player");
	
	if ( level >= 20 and not IsKioskModeEnabled() ) then
		local nextTab = _G["SpellBookFrameTabButton"..tabIndex];
		nextTab:Show();
		nextTab.bookType = BOOKTYPE_CORE_ABILITIES;
		nextTab.binding = "TOGGLECOREABILITIESBOOK";
		nextTab:SetText(SpellBookInfo[BOOKTYPE_CORE_ABILITIES].title);
		tabIndex = tabIndex+1;
	end
	
	
	-- Make sure the correct tab is selected
	for i=1,MaxSpellBookTypes do
		local tab = _G["SpellBookFrameTabButton"..i];
		PanelTemplates_TabResize(tab, 0, nil, 40);
		if ( tab.bookType == SpellBookFrame.bookType ) then
			PanelTemplates_SelectTab(tab);
			SpellBookFrame.currentTab = tab;
		else
			PanelTemplates_DeselectTab(tab);
		end
	end
	
	-- setup display
	for i, frame in ipairs(SpellBookFrames) do
		local found = false;
		for j,frame2 in ipairs(SpellBookInfo[SpellBookFrame.bookType].showFrames) do
			if (frame == frame2) then
				_G[frame]:Show();
				found = true;
				break;
			end
		end
		if (found == false) then
			_G[frame]:Hide();
		end
	end

	if SpellBookInfo[SpellBookFrame.bookType].bgFileL then
		SpellBookPage1:SetTexture(SpellBookInfo[SpellBookFrame.bookType].bgFileL);
	else	
		SpellBookPage1:SetTexture("Interface\\Spellbook\\Spellbook-Page-1");
	end
	if SpellBookInfo[SpellBookFrame.bookType].bgFileR then
		SpellBookPage2:SetTexture(SpellBookInfo[SpellBookFrame.bookType].bgFileR);
	else	
		SpellBookPage2:SetTexture("Interface\\Spellbook\\Spellbook-Page-2");
	end
	
	SpellBookFrameTitleText:SetText(SpellBookInfo[SpellBookFrame.bookType].title);
	
	local tabUpdate = SpellBookInfo[SpellBookFrame.bookType].updateFunc;
	if(tabUpdate) then
		tabUpdate()
	end
end

function SpellBookFrame_UpdateSpells ()
	for i = 1, SPELLS_PER_PAGE do
		_G["SpellButton" .. i]:Show();
		SpellButton_UpdateButton(_G["SpellButton" .. i]);
	end

	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		SpellBookPage1:SetDesaturated(_G["SpellBookSkillLineTab"..SpellBookFrame.selectedSkillLine].isOffSpec);
		SpellBookPage2:SetDesaturated(_G["SpellBookSkillLineTab"..SpellBookFrame.selectedSkillLine].isOffSpec);
	else
		SpellBookPage1:SetDesaturated(false);
		SpellBookPage2:SetDesaturated(false);
	end
end

function SpellBookFrame_UpdatePages()
	local currentPage, maxPages = SpellBook_GetCurrentPage();
	if ( maxPages == nil or maxPages == 0 ) then
		return;
	end
	if ( currentPage > maxPages ) then
		if (SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
			SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] = maxPages;
		else
			SPELLBOOK_PAGENUMBERS[SpellBookFrame.bookType] = maxPages;
		end
		currentPage = maxPages;
		if ( currentPage == 1 ) then
			SpellBookPrevPageButton:Disable();
		else
			SpellBookPrevPageButton:Enable();
		end
		if ( currentPage == maxPages ) then
			SpellBookNextPageButton:Disable();
		else
			SpellBookNextPageButton:Enable();
		end
	end
	if ( currentPage == 1 ) then
		SpellBookPrevPageButton:Disable();
	else
		SpellBookPrevPageButton:Enable();
	end
	if ( currentPage == maxPages ) then
		SpellBookNextPageButton:Disable();
	else
		SpellBookNextPageButton:Enable();
	end
	SpellBookPageText:SetFormattedText(PAGE_NUMBER, currentPage);
end

function SpellBookFrame_PlayOpenSound()
	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		PlaySound("igSpellBookOpen");
	elseif ( SpellBookFrame.bookType == BOOKTYPE_PET ) then
		-- Need to change to pet book open sound
		PlaySound("igAbilityOpen");
	else
		PlaySound("igSpellBookOpen");
	end
end

function SpellBookFrame_PlayCloseSound()
	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		PlaySound("igSpellBookClose");
	else
		-- Need to change to pet book close sound
		PlaySound("igAbilityClose");
	end
end

function SpellBookFrame_OnHide(self)
	HelpPlate_Hide();
	SpellBookFrame_PlayCloseSound();

	-- Stop the flash frame from flashing if its still flashing.. flash flash flash
	UIFrameFlashStop(SpellBookTabFlashFrame);
	-- Hide all the flashing textures
	for i=1, MAX_SKILLLINE_TABS do
		_G["SpellBookSkillLineTab"..i.."Flash"]:Hide();
	end

	-- Hide multibar slots
	MultiActionBar_HideAllGrids();
	
	SpellLockedTooltip:Hide();
	
	-- Do this last, it can cause taint.
	UpdateMicroButtons();
end

function SpellButton_OnLoad(self) 
	self:RegisterForDrag("LeftButton");
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

function SpellButton_OnEvent(self, event, ...)
	if ( event == "SPELLS_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" ) then
		-- need to listen for UPDATE_SHAPESHIFT_FORM because attack icons change when the shapeshift form changes
		SpellButton_UpdateButton(self);
	elseif ( event == "SPELL_UPDATE_COOLDOWN" ) then
		SpellButton_UpdateCooldown(self);
		-- Update tooltip
		if ( GameTooltip:GetOwner() == self ) then
			SpellButton_OnEnter(self);
		end
	elseif ( event == "CURRENT_SPELL_CAST_CHANGED" ) then
		SpellButton_UpdateSelection(self);
	elseif ( event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE" or event == "ARCHAEOLOGY_CLOSED" ) then
		SpellButton_UpdateSelection(self);
	elseif ( event == "PET_BAR_UPDATE" ) then
		if ( SpellBookFrame.bookType == BOOKTYPE_PET ) then
			SpellButton_UpdateButton(self);
		end
	end
end

function SpellButton_OnShow(self)
	self:RegisterEvent("SPELLS_CHANGED");
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM");
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
	self:RegisterEvent("TRADE_SKILL_SHOW");
	self:RegisterEvent("TRADE_SKILL_CLOSE");
	self:RegisterEvent("ARCHAEOLOGY_CLOSED");
	self:RegisterEvent("PET_BAR_UPDATE");

	--SpellButton_UpdateButton(self);
end

function SpellButton_OnHide(self)
	self:UnregisterEvent("SPELLS_CHANGED");
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
	self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM");
	self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED");
	self:UnregisterEvent("TRADE_SKILL_SHOW");
	self:UnregisterEvent("TRADE_SKILL_CLOSE");
	self:UnregisterEvent("ARCHAEOLOGY_CLOSED");
	self:UnregisterEvent("PET_BAR_UPDATE");
end
 
function SpellButton_OnEnter(self)
	local slot = SpellBook_GetSpellBookSlot(self);
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	if ( GameTooltip:SetSpellBookItem(slot, SpellBookFrame.bookType) ) then
		self.UpdateTooltip = SpellButton_OnEnter;
	else
		self.UpdateTooltip = nil;
	end
end

function SpellButton_OnClick(self, button)
	local slot, slotType = SpellBook_GetSpellBookSlot(self);
	if ( slot > MAX_SPELLS or slotType == "FUTURESPELL") then
		return;
	end

	if ( HasPendingGlyphCast() and SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		local slotType, spellID = GetSpellBookItemInfo(slot, SpellBookFrame.bookType);
		if (slotType == "SPELL") then
			if ( HasAttachedGlyph(spellID) ) then
				if ( IsPendingGlyphRemoval() ) then
					StaticPopup_Show("CONFIRM_GLYPH_REMOVAL", nil, nil, {name = GetCurrentGlyphNameForSpell(spellID), id = spellID});
				else
					StaticPopup_Show("CONFIRM_GLYPH_PLACEMENT", nil, nil, {name = GetPendingGlyphName(), currentName = GetCurrentGlyphNameForSpell(spellID), id = spellID});
				end
			else
				AttachGlyphToSpell(spellID);
			end
		end
		return;
	end

	if ( button ~= "LeftButton" and SpellBookFrame.bookType == BOOKTYPE_PET ) then
		if ( self.offSpecID == 0 ) then
			ToggleSpellAutocast(slot, SpellBookFrame.bookType);
		end
	else
		local _, id = GetSpellBookItemInfo(slot, SpellBookFrame.bookType);
		if (slotType == "FLYOUT") then
			SpellFlyout:Toggle(id, self, "RIGHT", 1, false, self.offSpecID, true);
			SpellFlyout:SetBorderColor(181/256, 162/256, 90/256);
		else
			if ( SpellBookFrame.bookType ~= BOOKTYPE_SPELLBOOK or self.offSpecID == 0 ) then
				CastSpell(slot, SpellBookFrame.bookType);
			end
		end
		SpellButton_UpdateSelection(self);
	end
end

function SpellButton_OnModifiedClick(self, button) 
	local slot = SpellBook_GetSpellBookSlot(self);
	if ( slot > MAX_SPELLS ) then
		return;
	end
	if ( IsModifiedClick("CHATLINK") ) then
		if ( MacroFrameText and MacroFrameText:HasFocus() ) then
			local spellName, subSpellName = GetSpellBookItemName(slot, SpellBookFrame.bookType);
			if ( spellName and not IsPassiveSpell(slot, SpellBookFrame.bookType) ) then
				if ( subSpellName and (strlen(subSpellName) > 0) ) then
					ChatEdit_InsertLink(spellName.."("..subSpellName..")");
				else
					ChatEdit_InsertLink(spellName);
				end
			end
			return;
		else
			local spellLink, tradeSkillLink = GetSpellLink(slot, SpellBookFrame.bookType);
			if ( tradeSkillLink ) then
				ChatEdit_InsertLink(tradeSkillLink);
			elseif ( spellLink ) then
				ChatEdit_InsertLink(spellLink);
			end
			return;
		end
	end
	if ( IsModifiedClick("PICKUPACTION") ) then
		PickupSpellBookItem(slot, SpellBookFrame.bookType);
		return;
	end
	if ( IsModifiedClick("SELFCAST") ) then
		CastSpell(slot, SpellBookFrame.bookType, true);
		SpellButton_UpdateSelection(self);
		return;
	end
end

function SpellButton_OnDrag(self) 
	local slot, slotType = SpellBook_GetSpellBookSlot(self);
	if (not slot or slot > MAX_SPELLS or not _G[self:GetName().."IconTexture"]:IsShown() or (slotType == "FUTURESPELL")) then
		return;
	end
	self:SetChecked(false);
	PickupSpellBookItem(slot, SpellBookFrame.bookType);
end

function SpellButton_UpdateSelection(self)
	local slot = SpellBook_GetSpellBookSlot(self);
	if ( slot and IsSelectedSpellBookItem(slot, SpellBookFrame.bookType) ) then
		self:SetChecked(true);
	else
		self:SetChecked(false);
	end
end

function SpellButton_UpdateCooldown(self)
	local cooldown = self.cooldown;
	local slot, slotType = SpellBook_GetSpellBookSlot(self);
	if (slot) then
		local start, duration, enable = GetSpellCooldown(slot, SpellBookFrame.bookType);
		if (cooldown and start and duration) then
			if (enable) then
				cooldown:Hide();
			else
				cooldown:Show();
			end
			CooldownFrame_SetTimer(cooldown, start, duration, enable);
		else
			cooldown:Hide();
		end
	end
end

function SpellButton_UpdateButton(self)
	if SpellBookFrame.bookType == BOOKTYPE_PROFESSION then
		UpdateProfessionButton(self);
		return;
	end

	if ( not SpellBookFrame.selectedSkillLine ) then
		SpellBookFrame.selectedSkillLine = 2;
	end
	local temp, texture, offset, numSlots, isGuild, offSpecID = GetSpellTabInfo(SpellBookFrame.selectedSkillLine);
	SpellBookFrame.selectedSkillLineNumSlots = numSlots;
	SpellBookFrame.selectedSkillLineOffset = offset;
	local isOffSpec = (offSpecID ~= 0) and (SpellBookFrame.bookType == BOOKTYPE_SPELL);
	self.offSpecID = offSpecID;
	
	if (not self.SpellName.shadowX) then
		self.SpellName.shadowX, self.SpellName.shadowY = self.SpellName:GetShadowOffset();
	end

	local slot, slotType, slotID = SpellBook_GetSpellBookSlot(self);
	local name = self:GetName();
	local iconTexture = _G[name.."IconTexture"];
	local spellString = _G[name.."SpellName"];
	local subSpellString = _G[name.."SubSpellName"];
	local cooldown = _G[name.."Cooldown"];
	local autoCastableTexture = _G[name.."AutoCastable"];
	local slotFrame = _G[name.."SlotFrame"];

	-- Hide flyout if it's currently open
	if (SpellFlyout:IsShown() and SpellFlyout:GetParent() == self)  then
		SpellFlyout:Hide();
	end

	local highlightTexture = _G[name.."Highlight"];
	local texture;
	if ( slot ) then
		texture = GetSpellBookItemTexture(slot, SpellBookFrame.bookType);
	end

	-- If no spell, hide everything and return, or kiosk mode and future spell
	if ( not texture or (strlen(texture) == 0) or (slotType == "FUTURESPELL" and IsKioskModeEnabled())) then
		iconTexture:Hide();
		spellString:Hide();
		subSpellString:Hide();
		cooldown:Hide();
		autoCastableTexture:Hide();
		SpellBook_ReleaseAutoCastShine(self.shine);
		self.shine = nil;
		highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
		self:SetChecked(false);
		slotFrame:Hide();
		self.IconTextureBg:Hide();
		self.SeeTrainerString:Hide();
		self.RequiredLevelString:Hide();
		self.UnlearnedFrame:Hide();
		self.TrainFrame:Hide();
		self.TrainTextBackground:Hide();
		self.TrainBook:Hide();
		self.FlyoutArrow:Hide();
		self:Disable();
		self.TextBackground:SetDesaturated(isOffSpec);
		self.TextBackground2:SetDesaturated(isOffSpec);
		self.EmptySlot:SetDesaturated(isOffSpec);
		return;
	else
		self:Enable();
	end

	SpellButton_UpdateCooldown(self);

	local autoCastAllowed, autoCastEnabled = GetSpellAutocast(slot, SpellBookFrame.bookType);
	if ( autoCastAllowed ) then
		autoCastableTexture:Show();
	else
		autoCastableTexture:Hide();
	end
	if ( autoCastEnabled and not self.shine ) then
		self.shine = SpellBook_GetAutoCastShine();
		self.shine:Show();
		self.shine:SetParent(self);
		self.shine:SetPoint("CENTER", self, "CENTER");
		AutoCastShine_AutoCastStart(self.shine);
	elseif ( autoCastEnabled ) then
		self.shine:Show();
		self.shine:SetParent(self);
		self.shine:SetPoint("CENTER", self, "CENTER");
		AutoCastShine_AutoCastStart(self.shine);
	elseif ( not autoCastEnabled ) then
		SpellBook_ReleaseAutoCastShine(self.shine);
		self.shine = nil;
	end

	local spellName, subSpellName = GetSpellBookItemName(slot, SpellBookFrame.bookType);
	local isPassive = IsPassiveSpell(slot, SpellBookFrame.bookType);
	self.isPassive = isPassive;

	if (slotType == "FLYOUT") then
		SetClampedTextureRotation(self.FlyoutArrow, 90);
		self.FlyoutArrow:Show();
	else
		self.FlyoutArrow:Hide();
	end
	
	local specs =  {GetSpecsForSpell(slot, SpellBookFrame.bookType)};
	local specName = table.concat(specs, PLAYER_LIST_DELIMITER);
	if ( subSpellName == "" ) then
		if ( IsTalentSpell(slot, SpellBookFrame.bookType) ) then
			if ( isPassive ) then
				subSpellName = TALENT_PASSIVE
			else
				subSpellName = TALENT
			end
		elseif ( isPassive ) then
			subSpellName = SPELL_PASSIVE;
		end
	end			

	-- If there is no spell sub-name, move the bottom row of text up
	if ( subSpellName == "" ) then
		self.SpellSubName:SetHeight(6);
	else
		self.SpellSubName:SetHeight(0);
	end

	iconTexture:SetTexture(texture);
	spellString:SetText(spellName);
	subSpellString:SetText(subSpellName);
	iconTexture:Show();
	spellString:Show();
	subSpellString:Show();
	
	if (not (slotType == "FUTURESPELL")) then
		slotFrame:Show();
		self.UnlearnedFrame:Hide();
		self.TrainFrame:Hide();
		self.IconTextureBg:Hide();
		iconTexture:SetAlpha(1);
		iconTexture:SetDesaturated(false);
		self.RequiredLevelString:Hide();
		self.SeeTrainerString:Hide();
		self.TrainTextBackground:Hide();
		self.TrainBook:Hide();
		self.SpellName:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		self.SpellName:SetShadowOffset(self.SpellName.shadowX, self.SpellName.shadowY);
		self.SpellName:SetPoint("LEFT", self, "RIGHT", 8, 4);
		self.SpellSubName:SetTextColor(0, 0, 0);
		if ( slotType == "SPELL" and not isOffSpec ) then
			local _, spellID = GetSpellBookItemInfo(slot, SpellBookFrame.bookType);
			if (IsSpellValidForPendingGlyph(spellID)) then
				self.AbilityHighlight:Show();
				self.AbilityHighlightAnim:Play();
			else
				self.AbilityHighlightAnim:Stop();
				self.AbilityHighlight:Hide();
			end
		else
			self.AbilityHighlightAnim:Stop();
			self.AbilityHighlight:Hide();
		end
		
		if ( slotType == "SPELL" and isOffSpec ) then
			local level = GetSpellLevelLearned(slotID);
			if ( level and level > UnitLevel("player") ) then
				self.RequiredLevelString:Show();
				self.RequiredLevelString:SetFormattedText(SPELLBOOK_AVAILABLE_AT, level);
				self.RequiredLevelString:SetTextColor(0.25, 0.12, 0);
			end
		end
	else
		local level = GetSpellAvailableLevel(slot, SpellBookFrame.bookType);
		slotFrame:Hide();
		self.IconTextureBg:Show();
		iconTexture:SetAlpha(0.5);
		iconTexture:SetDesaturated(true);
		if (IsCharacterNewlyBoosted()) then
			self.SeeTrainerString:Hide();
			self.UnlearnedFrame:Show();
			self.TrainFrame:Hide();
			self.TrainTextBackground:Hide();
			self.TrainBook:Hide();
			self.RequiredLevelString:Show();
			self.RequiredLevelString:SetText(BOOSTED_CHAR_SPELL_TEMPLOCK);
			self.RequiredLevelString:SetTextColor(0.25, 0.12, 0);
			self.SpellName:SetTextColor(0.25, 0.12, 0);
			self.SpellSubName:SetTextColor(0.25, 0.12, 0);
			self.SpellName:SetShadowOffset(0, 0);
			self.SpellName:SetPoint("LEFT", self, "RIGHT", 8, 6);
		elseif (level and level > UnitLevel("player")) then
			self.SeeTrainerString:Hide();
			self.RequiredLevelString:Show();
			self.RequiredLevelString:SetFormattedText(SPELLBOOK_AVAILABLE_AT, level);
			self.RequiredLevelString:SetTextColor(0.25, 0.12, 0);
			self.UnlearnedFrame:Show();
			self.TrainFrame:Hide();
			self.TrainTextBackground:Hide();
			self.TrainBook:Hide();
			self.SpellName:SetTextColor(0.25, 0.12, 0);
			self.SpellSubName:SetTextColor(0.25, 0.12, 0);
			self.SpellName:SetShadowOffset(0, 0);
			self.SpellName:SetPoint("LEFT", self, "RIGHT", 8, 6);
		else
			self.SeeTrainerString:Show();
			self.RequiredLevelString:Hide();
			self.TrainFrame:Show();
			self.UnlearnedFrame:Hide();
			self.TrainTextBackground:Show();
			self.TrainBook:Show();
			self.SpellName:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
			self.SpellName:SetShadowOffset(self.SpellName.shadowX, self.SpellName.shadowY);
			self.SpellName:SetPoint("LEFT", self, "RIGHT", 24, 8);
			self.SpellSubName:SetTextColor(0, 0, 0);
		end
	end

	if ( isPassive ) then
		highlightTexture:SetTexture("Interface\\Buttons\\UI-PassiveHighlight");
		slotFrame:Hide();
		self.UnlearnedFrame:Hide();
	else
		highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
	end

	-- set all the desaturated offspec pages
	slotFrame:SetDesaturated(isOffSpec);
	self.TextBackground:SetDesaturated(isOffSpec);
	self.TextBackground2:SetDesaturated(isOffSpec);
	self.EmptySlot:SetDesaturated(isOffSpec);
	self.FlyoutArrow:SetDesaturated(isOffSpec);
	if (isOffSpec) then
		iconTexture:SetDesaturated(isOffSpec);
		self.SpellName:SetTextColor(0.75, 0.75, 0.75);
		self.RequiredLevelString:SetTextColor(0.1, 0.1, 0.1);
		autoCastableTexture:Hide();
		SpellBook_ReleaseAutoCastShine(self.shine);
		self.shine = nil;
		self:SetChecked(false);
	else
		SpellButton_UpdateSelection(self);
	end
end

function SpellBookPrevPageButton_OnClick()
	local pageNum = SpellBook_GetCurrentPage() - 1;
	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		PlaySound("igAbiliityPageTurn");
		SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] = pageNum;
	else
		-- Need to change to pet book pageturn sound
		PlaySound("igAbiliityPageTurn");
		SPELLBOOK_PAGENUMBERS[SpellBookFrame.bookType] = pageNum;
	end
	SpellBookFrame_Update();
end

function SpellBookNextPageButton_OnClick()
	local pageNum = SpellBook_GetCurrentPage() + 1;
	if ( SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
		PlaySound("igAbiliityPageTurn");
		SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] = pageNum;
	else
		-- Need to change to pet book pageturn sound
		PlaySound("igAbiliityPageTurn");
		SPELLBOOK_PAGENUMBERS[SpellBookFrame.bookType] = pageNum;
	end
	SpellBookFrame_Update();
end

function SpellBookFrame_OnMouseWheel(self, value, scrollBar)
	--do nothing if not on an appropriate book type
	if(SpellBookFrame.bookType ~= BOOKTYPE_SPELL and SpellBookFrame.bookType ~= BOOKTYPE_CORE_ABILITIES) then
		return;
	end

	local currentPage, maxPages = SpellBook_GetCurrentPage();

	if(value > 0) then
		if(currentPage > 1) then
			SpellBookPrevPageButton_OnClick()
		end
	else 
		if(currentPage < maxPages) then
			SpellBookNextPageButton_OnClick()
		end
	end
end


function SpellBookSkillLineTab_OnClick(self)
	local id = self:GetID();
	if ( SpellBookFrame.selectedSkillLine ~= id ) then
		PlaySound("igAbiliityPageTurn");
		SpellBookFrame.selectedSkillLine = id;
		SpellBookFrame_Update();
	else
		self:SetChecked(true);
	end
	
	-- Stop tab flashing
	if ( self ) then
		local tabFlash = _G[self:GetName().."Flash"];
		if ( tabFlash ) then
			tabFlash:Hide();
		end
	end
end

function SpellBookFrameTabButton_OnClick(self)
	self:Disable();
	if SpellBookFrame.currentTab then
		SpellBookFrame.currentTab:Enable();
	end
	SpellBookFrame.currentTab = self;
	ToggleSpellBook(self.bookType);
end

function SpellBook_GetSpellBookSlot(spellButton)
	local id = spellButton:GetID()
	if ( SpellBookFrame.bookType == BOOKTYPE_PROFESSION) then
		return id + spellButton:GetParent().spellOffset;
	elseif ( SpellBookFrame.bookType == BOOKTYPE_PET ) then
		return id + (SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[BOOKTYPE_PET] - 1));
	else
		local relativeSlot = id + ( SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] - 1));
		if ( SpellBookFrame.selectedSkillLineNumSlots and relativeSlot <= SpellBookFrame.selectedSkillLineNumSlots) then
			local slot = SpellBookFrame.selectedSkillLineOffset + relativeSlot;
			local slotType, slotID = GetSpellBookItemInfo(slot, SpellBookFrame.bookType);
			return slot, slotType, slotID;
		else
			return nil, nil;
		end
	end
end

function SpellBook_GetButtonForID(id)
	-- Currently the spell book is mapped such that odd numbered buttons from 1 - 11 match id 1 - 6, while even numbered buttons from 2 - 12 match 7 - 12
	if (id > 6) then
		return _G["SpellButton"..((id - 6) * 2)];
	else
		return _G["SpellButton"..(((id - 1) * 2) + 1)];
	end
end

function SpellBookFrame_OpenToPageForSlot(slot, reason)
	local alreadyOpen = SpellBookFrame:IsShown();
	ShowUIPanel(SpellBookFrame);
	if (SpellBookFrame.selectedSkillLine ~= 2) then
		SpellBookFrame.selectedSkillLine = 2;
		SpellBookFrame_Update();
	end

	if (alreadyOpen) then
		local page = SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine];
		for i = 1, 12 do
			local slot = (i + ( SPELLS_PER_PAGE * (page - 1))) + SpellBookFrame.selectedSkillLineOffset;
			local slotType, spellID = GetSpellBookItemInfo(slot, SpellBookFrame.bookType);
			if (slotType == "SPELL") then
				if (IsSpellValidForPendingGlyph(spellID)) then
					SpellBookFrame_Update();
					return;
				end
			end
		end
	end

	local relativeSlot = slot - SpellBookFrame.selectedSkillLineOffset;
	local page = math.floor(relativeSlot / SPELLS_PER_PAGE) + 1;
	SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] = page;
	SpellBookFrame_Update();
	local id = relativeSlot - ( SPELLS_PER_PAGE * (page - 1) );
	local button = SpellBook_GetButtonForID(id);
	if (reason == OPEN_REASON_PENDING_GLYPH) then
		button.AbilityHighlight:Show();
		button.AbilityHighlightAnim:Play();
	elseif (reason == OPEN_REASON_ACTIVATED_GLYPH) then
		button.AbilityHighlightAnim:Stop();
		button.AbilityHighlight:Hide();
		button.GlyphActivate:Show();
		button.GlyphActivateAnim:Play();
	end
end

function SpellBookFrame_ClearAbilityHighlights()
	for i = 1, SPELLS_PER_PAGE do
		local button = _G["SpellButton"..i];
		button.AbilityHighlightAnim:Stop();
		button.AbilityHighlight:Hide();
	end
end

function SpellBook_GetCurrentPage()
	local currentPage, maxPages;
	local numPetSpells = HasPetSpells() or 0;
	if ( SpellBookFrame.bookType == BOOKTYPE_PET ) then
		currentPage = SPELLBOOK_PAGENUMBERS[BOOKTYPE_PET];
		maxPages = ceil(numPetSpells/SPELLS_PER_PAGE);
	elseif ( SpellBookFrame.bookType == BOOKTYPE_SPELL) then
		currentPage = SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine];
		local name, texture, offset, numSlots = GetSpellTabInfo(SpellBookFrame.selectedSkillLine);
		maxPages = ceil(numSlots/SPELLS_PER_PAGE);
	elseif ( SpellBookFrame.bookType == BOOKTYPE_CORE_ABILITIES) then
		currentPage = 1;
		maxPages = 1;
	end
	return currentPage, maxPages;
end

local maxShines = 1;
local shineGet = {}
function SpellBook_GetAutoCastShine ()
	local shine = shineGet[1];
	
	if ( shine ) then
		tremove(shineGet, 1);
	else
		shine = CreateFrame("FRAME", "AutocastShine" .. maxShines, SpellBookFrame, "SpellBookShineTemplate");
		maxShines = maxShines + 1;
	end
	
	return shine;
end

function SpellBook_ReleaseAutoCastShine (shine)
	if ( not shine ) then
		return;
	end
	
	shine:Hide();
	AutoCastShine_AutoCastStop(shine);
	tinsert(shineGet, shine);
end

-------------------------------------------------------------------
--------------------- Update functions for tabs --------------------
-------------------------------------------------------------------
function SpellBookFrame_UpdateSkillLineTabs()
	local numSkillLineTabs = GetNumSpellTabs();
	for i=1, MAX_SKILLLINE_TABS do
		local skillLineTab = _G["SpellBookSkillLineTab"..i];
		local prevTab = _G["SpellBookSkillLineTab"..i-1];
		if ( i <= numSkillLineTabs and SpellBookFrame.bookType == BOOKTYPE_SPELL ) then
			local name, texture, _, _, isGuild, offSpecID, shouldHide = GetSpellTabInfo(i);
			
			if ( shouldHide ) then
				_G["SpellBookSkillLineTab"..i.."Flash"]:Hide();
				skillLineTab:Hide();
			else
				local isOffSpec = (offSpecID ~= 0);
				skillLineTab:SetNormalTexture(texture);
				skillLineTab.tooltip = name;
				skillLineTab:Show();
				skillLineTab.isOffSpec = isOffSpec;
				if(texture) then
					skillLineTab:GetNormalTexture():SetDesaturated(isOffSpec);
				end

				-- Guild tab gets additional space
				if (prevTab) then
					if (isGuild) then
						skillLineTab:SetPoint("TOPLEFT", prevTab, "BOTTOMLEFT", 0, -46);
					elseif (isOffSpec and not prevTab.isOffSpec) then
						skillLineTab:SetPoint("TOPLEFT", prevTab, "BOTTOMLEFT", 0, -40);
					else
						skillLineTab:SetPoint("TOPLEFT", prevTab, "BOTTOMLEFT", 0, -17);
					end
				end
				
				-- Guild tab must show the Guild Banner
				if (isGuild) then
					skillLineTab:SetNormalTexture("Interface\\SpellBook\\GuildSpellbooktabBG");
					skillLineTab.TabardEmblem:Show();
					skillLineTab.TabardIconFrame:Show();
					SetLargeGuildTabardTextures("player", skillLineTab.TabardEmblem, skillLineTab:GetNormalTexture(), skillLineTab.TabardIconFrame);
				else
					skillLineTab.TabardEmblem:Hide();
					skillLineTab.TabardIconFrame:Hide();
				end

				-- Set the selected tab
				if ( SpellBookFrame.selectedSkillLine == i ) then
					skillLineTab:SetChecked(true);
					--SpellBookSpellGroupText:SetText(name);
				else
					skillLineTab:SetChecked(false);
				end
			end
		else
			_G["SpellBookSkillLineTab"..i.."Flash"]:Hide();
			skillLineTab:Hide();
		end
	end
end

function SpellBook_UpdatePlayerTab()

	-- Setup skillline tabs
	local name, texture, offset, numSlots = GetSpellTabInfo(SpellBookFrame.selectedSkillLine);
	SpellBookFrame.selectedSkillLineOffset = offset;
	SpellBookFrame.selectedSkillLineNumSlots = numSlots;
	
	SpellBookFrame_UpdatePages();

	SpellBookFrame_UpdateSkillLineTabs();

	SpellBookFrame_UpdateSpells();
end


function SpellBook_UpdatePetTab(showing)
	SpellBookFrame_UpdatePages();
	SpellBookFrame_UpdateSpells();
end

function UpdateProfessionButton(self)
	local spellIndex = self:GetID() + self:GetParent().spellOffset;
	local texture = GetSpellBookItemTexture(spellIndex, SpellBookFrame.bookType);
	local spellName, subSpellName = GetSpellBookItemName(spellIndex, SpellBookFrame.bookType);
	local isPassive = IsPassiveSpell(spellIndex, SpellBookFrame.bookType);
	if ( isPassive ) then
		self.highlightTexture:SetTexture("Interface\\Buttons\\UI-PassiveHighlight");
		self.spellString:SetTextColor(PASSIVE_SPELL_FONT_COLOR.r, PASSIVE_SPELL_FONT_COLOR.g, PASSIVE_SPELL_FONT_COLOR.b);
	else
		self.highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
		self.spellString:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
	
	self.iconTexture:SetTexture(texture);
	local start, duration, enable = GetSpellCooldown(spellIndex, SpellBookFrame.bookType);
	CooldownFrame_SetTimer(self.cooldown, start, duration, enable);
	if ( enable == 1 ) then
		self.iconTexture:SetVertexColor(1.0, 1.0, 1.0);
	else
		self.iconTexture:SetVertexColor(0.4, 0.4, 0.4);
	end

	if ( self:GetParent().specializationIndex >= 0 and self:GetID() == self:GetParent().specializationOffset) then
		self.unlearn:Show();
	else
		self.unlearn:Hide();
	end
	
	self.spellString:SetText(spellName);
	self.subSpellString:SetText(subSpellName);	
	self.iconTexture:SetTexture(texture);
	
	SpellButton_UpdateSelection(self);
end

function FormatProfession(frame, index)
	if index then
		frame.missingHeader:Hide();
		frame.missingText:Hide();
		
		local name, texture, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(index);
		frame.skillName = name;
		frame.spellOffset = spelloffset;
		frame.skillLine = skillLine;
		frame.specializationIndex = specializationIndex;
		frame.specializationOffset = specializationOffset;
		
		frame.statusBar:SetMinMaxValues(1,maxRank);
		frame.statusBar:SetValue(rank);
		
		local prof_title = "";
		for i=1,#PROFESSION_RANKS do
		    local value,title = PROFESSION_RANKS[i][1], PROFESSION_RANKS[i][2]; 
			if maxRank < value then break end
			prof_title = title;
		end
		frame.rank:SetText(prof_title);
		
		frame.statusBar:Show();
		if rank == maxRank then
			frame.statusBar.capRight:Show();
		else
			frame.statusBar.capRight:Hide();
		end
		-- trial cap
		if ( GameLimitedMode_IsActive() ) then
			local _, _, profCap = GetRestrictedAccountData();
			if rank >= profCap then
				frame.statusBar.capped:Show();
				frame.statusBar.rankText:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
				frame.statusBar.tooltip = RED_FONT_COLOR_CODE..CAP_REACHED_TRIAL..FONT_COLOR_CODE_CLOSE;
			else
				frame.statusBar.capped:Hide();
				frame.statusBar.rankText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				frame.statusBar.tooltip = nil;
			end
		end
		
		if frame.icon and texture then
			SetPortraitToTexture(frame.icon, texture);	
			frame.unlearn:Show();
		end
		
		frame.professionName:SetText(name);
		
		if ( rankModifier > 0 ) then
			frame.statusBar.rankText:SetFormattedText(TRADESKILL_RANK_WITH_MODIFIER, rank, rankModifier, maxRank);
		else
			frame.statusBar.rankText:SetFormattedText(TRADESKILL_RANK, rank, maxRank);
		end

		
		if numSpells <= 0 then		
			frame.button1:Hide();
			frame.button2:Hide();
		elseif numSpells == 1 then		
			frame.button2:Hide();
			frame.button1:Show();
			UpdateProfessionButton(frame.button1);		
		else -- if numSpells >= 2 then	
			frame.button1:Show();
			frame.button2:Show();
			UpdateProfessionButton(frame.button1);			
			UpdateProfessionButton(frame.button2);
		end
		
		if numSpells >  2 then
			local errorStr = "Found "..numSpells.." skills for "..name.." the max is 2:"
			for i=1,numSpells do
				errorStr = errorStr.." ("..GetSpellBookItemName(i + spelloffset, SpellBookFrame.bookType)..")";
			end
			assert(false, errorStr)
		end
	else		
		frame.missingHeader:Show();
		frame.missingText:Show();
		
		if frame.icon then
			SetPortraitToTexture(frame.icon, "Interface\\Icons\\INV_Scroll_04");	
			frame.unlearn:Hide();			
			frame.specialization:SetText("");
		end			
		frame.button1:Hide();
		frame.button2:Hide();
		frame.statusBar:Hide();
		frame.rank:SetText("");
		frame.professionName:SetText("");		
	end
end


function SpellBook_UpdateProfTab()
	local prof1, prof2, arch, fish, cook, firstAid = GetProfessions();
	FormatProfession(PrimaryProfession1, prof1);
	FormatProfession(PrimaryProfession2, prof2);
	FormatProfession(SecondaryProfession1, arch);
	FormatProfession(SecondaryProfession2, fish);
	FormatProfession(SecondaryProfession3, cook);
	FormatProfession(SecondaryProfession4, firstAid);
	SpellBookPage1:SetDesaturated(false);
	SpellBookPage2:SetDesaturated(false);	
end


-- *************************************************************************************

-- String prefixes for text
SPEC_CORE_ABILITY_TEXT = {}
SPEC_CORE_ABILITY_TEXT[250] = "DK_BLOOD";
SPEC_CORE_ABILITY_TEXT[251] = "DK_FROST";
SPEC_CORE_ABILITY_TEXT[252] = "DK_UNHOLY";

SPEC_CORE_ABILITY_TEXT[102] = "DRUID_BALANCE";
SPEC_CORE_ABILITY_TEXT[103] = "DRUID_FERAL";
SPEC_CORE_ABILITY_TEXT[104] = "DRUID_GUARDIAN";
SPEC_CORE_ABILITY_TEXT[105] = "DRUID_RESTO";

SPEC_CORE_ABILITY_TEXT[253] = "HUNTER_BM";
SPEC_CORE_ABILITY_TEXT[254] = "HUNTER_MM";
SPEC_CORE_ABILITY_TEXT[255] = "HUNTER_SV";

SPEC_CORE_ABILITY_TEXT[62] = "MAGE_ARCANE";
SPEC_CORE_ABILITY_TEXT[63] = "MAGE_FIRE";
SPEC_CORE_ABILITY_TEXT[64] = "MAGE_FROST";

SPEC_CORE_ABILITY_TEXT[268] = "MONK_BREW";
SPEC_CORE_ABILITY_TEXT[270] = "MONK_MIST";
SPEC_CORE_ABILITY_TEXT[269] = "MONK_WIND";

SPEC_CORE_ABILITY_TEXT[65] = "PALADIN_HOLY";
SPEC_CORE_ABILITY_TEXT[66] = "PALADIN_PROT";
SPEC_CORE_ABILITY_TEXT[70] = "PALADIN_RET";

SPEC_CORE_ABILITY_TEXT[256] = "PRIEST_DISC";
SPEC_CORE_ABILITY_TEXT[257] = "PRIEST_HOLY";
SPEC_CORE_ABILITY_TEXT[258] = "PRIEST_SHADOW";

SPEC_CORE_ABILITY_TEXT[259] = "ROGUE_ASS";
SPEC_CORE_ABILITY_TEXT[260] = "ROGUE_COMBAT";
SPEC_CORE_ABILITY_TEXT[261] = "ROGUE_SUB";

SPEC_CORE_ABILITY_TEXT[262] = "SHAMAN_ELE";
SPEC_CORE_ABILITY_TEXT[263] = "SHAMAN_ENHANCE";
SPEC_CORE_ABILITY_TEXT[264] = "SHAMAN_RESTO";

SPEC_CORE_ABILITY_TEXT[265] = "WARLOCK_AFFLICTION";
SPEC_CORE_ABILITY_TEXT[266] = "WARLOCK_DEMO";
SPEC_CORE_ABILITY_TEXT[267] = "WARLOCK_DESTRO";

SPEC_CORE_ABILITY_TEXT[71] = "WARRIOR_ARMS";
SPEC_CORE_ABILITY_TEXT[72] = "WARRIOR_FURY";
SPEC_CORE_ABILITY_TEXT[73] = "WARRIOR_PROT";

SPEC_CORE_ABILITY_TEXT[577] = "DH_HAVOC";
SPEC_CORE_ABILITY_TEXT[581] = "DH_VENGEANCE";


-- Hardcoded spell id's for spec display
SPEC_CORE_ABILITY_DISPLAY = {}
SPEC_CORE_ABILITY_DISPLAY[250] = {	45902,	195182,	49998,	43265,	50842,	49576,	}; --Blood
SPEC_CORE_ABILITY_DISPLAY[251] = {	49143,	49184,	49020,	196770,	51128,	59057,	}; --Frost
SPEC_CORE_ABILITY_DISPLAY[252] = {	85948,	55090,	77575,	47541,	43265,	46584,	}; --Unholy

SPEC_CORE_ABILITY_DISPLAY[102] = {	194153,	8921,	78674,	190984,	93402,  191034,	}; --Balance
SPEC_CORE_ABILITY_DISPLAY[103] = {	1822,	5221,	52610,	1079, 	22568,		}; --Feral
SPEC_CORE_ABILITY_DISPLAY[104] = {	33917,	33745,	106832,	6807,	62606,	22842,	}; --Guardian
SPEC_CORE_ABILITY_DISPLAY[105] = {	33763,	774,	5185, 	8936,	48438,	18562,	}; --Restoration

SPEC_CORE_ABILITY_DISPLAY[253] = {	3044, 	77767, 	82692, 	34026,	53351,		}; --Beast Mastery
SPEC_CORE_ABILITY_DISPLAY[254] = {	19434,	185358,	185901,	186387,	2643,   185987,	}; --Marksmanship
SPEC_CORE_ABILITY_DISPLAY[255] = {	190928,	202800,	185855,	186270,	187708, 191433,	}; --Survival

SPEC_CORE_ABILITY_DISPLAY[62] = {	30451,	44425,	5143, 	114664,	12051,		}; --Arcane
SPEC_CORE_ABILITY_DISPLAY[63] = {	133,	11366,	108853,	190319,	2948,	195283,	}; --Fire
SPEC_CORE_ABILITY_DISPLAY[64] = {	116,	30455,	44614,	31687,	44549,	112965,	}; --Frost

SPEC_CORE_ABILITY_DISPLAY[268] = {	121253, 100780,	100784,	100787,	119582,	115308, }; --Brewmaster
SPEC_CORE_ABILITY_DISPLAY[270] = {	115151,	124682,	116670,	191837,	116694, 193884,	}; --Mistweaver
SPEC_CORE_ABILITY_DISPLAY[269] = {	100784,	107428,	100780,	137639,	113656,	101545,	}; --Windwalker

SPEC_CORE_ABILITY_DISPLAY[65] = {	20473,	85673,	82326,	19750,	53563,	82327,	}; --Holy
SPEC_CORE_ABILITY_DISPLAY[66] = {	31935,	35395,	20271,	85673,	53600,	31801,	}; --Protection
SPEC_CORE_ABILITY_DISPLAY[70] = {	35395,	184575,	20271,	85256,	53385,	185817,	}; --Retribution

SPEC_CORE_ABILITY_DISPLAY[256] = {	47540,	17,	2060,	2061,	132157,	596,	}; --Discipline
SPEC_CORE_ABILITY_DISPLAY[257] = {	2060,	2061,	139,	33076,	34861,	596,	}; --Holy
SPEC_CORE_ABILITY_DISPLAY[258] = {	8092,	205448,	589,	34914,	15407,	185916,	}; --Shadow

SPEC_CORE_ABILITY_DISPLAY[259] = {	8676,	111240,	1329,	5171,	1943,	32645,	}; --Assassination
SPEC_CORE_ABILITY_DISPLAY[260] = {	193315,	185763,	5171,	2098,	13877,	199804,	}; --Outlaw
SPEC_CORE_ABILITY_DISPLAY[261] = {	8676,	16511,	53,	5171,	1943,	2098,	}; --Subtlety

SPEC_CORE_ABILITY_DISPLAY[262] = {	8050,	51505,	403,	8042,	324,		}; --Elemental
SPEC_CORE_ABILITY_DISPLAY[263] = {	8050,	17364,	60103,	403,	73680,	51530,	}; --Enhancement
SPEC_CORE_ABILITY_DISPLAY[264] = {	974,	77472,	8004,	61295,	73920,	1064,	}; --Restoration

SPEC_CORE_ABILITY_DISPLAY[265] = {	172,	980,	30108,	689,	27243,	691,	}; --Affliction
SPEC_CORE_ABILITY_DISPLAY[266] = {	172,	686,	6353,	105174,	103958,	122351,	}; --Demonology
SPEC_CORE_ABILITY_DISPLAY[267] = {	348,	17962,	116858,	29722,	17877,		}; --Destruction

SPEC_CORE_ABILITY_DISPLAY[71] = {	100,	167105,	12294,	772,	1680,	163201,	}; --Arms
SPEC_CORE_ABILITY_DISPLAY[72] = {	23881,	85288,	184367,	18499,	190411,	184361, }; --Fury	
SPEC_CORE_ABILITY_DISPLAY[73] = {	23922,	20243,	2565,	190456,	6572,	6343,	}; --Protection

SPEC_CORE_ABILITY_DISPLAY[577] = {	195072,	198013,	162794,	162243	}; --Havoc
SPEC_CORE_ABILITY_DISPLAY[581] = {	}; --Vengeance	

function SpellBook_GetCoreAbilityButton(index)
	local button = SpellBookCoreAbilitiesFrame.Abilities[index];
	if ( not button ) then
		SpellBookCoreAbilitiesFrame.Abilities[index] = CreateFrame("BUTTON", nil, SpellBookCoreAbilitiesFrame, "CoreAbilitySpellTemplate");
		button = SpellBookCoreAbilitiesFrame.Abilities[index];
		button:SetPoint("TOP", SpellBookCoreAbilitiesFrame.Abilities[index-1], "BOTTOM", 0, -29);
	end
	return button;
end

function SpellBook_GetCoreAbilitySpecTab(index)
	local tab = SpellBookCoreAbilitiesFrame.SpecTabs[index];
	if ( not tab ) then
		SpellBookCoreAbilitiesFrame.SpecTabs[index] = CreateFrame("CHECKBUTTON", nil, SpellBookCoreAbilitiesFrame, "CoreAbilitiesSkillLineTabTemplate");
		tab = SpellBookCoreAbilitiesFrame.SpecTabs[index]
		tab:SetPoint("TOPLEFT", SpellBookCoreAbilitiesFrame.SpecTabs[index-1], "BOTTOMLEFT", 0, -17);
	end
	return tab;
end

function SpellBookCoreAbilitiesTab_OnClick(self)
	PlaySound("igAbiliityPageTurn");
	SpellBookCoreAbilitiesFrame.selectedSpec = self:GetID();
	SpellBook_UpdateCoreAbilitiesTab();
end

function SpellBookCoreAbilities_UpdateTabs()
	local numSpecs = GetNumSpecializations();
	local currentSpec = GetSpecialization();
	local sex = UnitSex("player")
	local index = 1;
	local tab;
	if ( currentSpec ) then
		tab = SpellBook_GetCoreAbilitySpecTab(index);
		local id, name, description, icon = GetSpecializationInfo(currentSpec, nil, nil, nil, sex);
		tab:SetID(currentSpec);
		tab:SetNormalTexture(icon);
		tab:SetChecked(SpellBookCoreAbilitiesFrame.selectedSpec == tab:GetID());
		tab.tooltip = name;
		tab:Show();
		index = index + 1;
	end
	
	tab = SpellBook_GetCoreAbilitySpecTab(2);
	if ( currentSpec ) then
		tab:SetPoint("TOPLEFT", SpellBookCoreAbilitiesFrame.SpecTabs[1], "BOTTOMLEFT", 0, -40);
	else
		tab:SetPoint("TOPLEFT", SpellBookCoreAbilitiesFrame.SpecTabs[1], "BOTTOMLEFT", 0, -17);
	end
	
	for i=1, numSpecs do
		if ( not currentSpec or currentSpec ~= i ) then
			tab = SpellBook_GetCoreAbilitySpecTab(index);
			local id, name, description, icon = GetSpecializationInfo(i, nil, nil, nil, sex);
			tab:SetID(i);
			tab:SetNormalTexture(icon);
			tab:SetChecked(SpellBookCoreAbilitiesFrame.selectedSpec == tab:GetID());
			tab:GetNormalTexture():SetDesaturated(currentSpec and not (currentSpec == i));
			tab.tooltip = name;
			tab:Show();
			index = index + 1;
		end
	end
	for i = numSpecs + 1, #SpellBookCoreAbilitiesFrame.SpecTabs do
		SpellBook_GetCoreAbilitySpecTab(i):Hide();
	end
end

function SpellBook_UpdateCoreAbilitiesTab()
	SpellBookFrame_UpdatePages();
	SpellBookCoreAbilities_UpdateTabs();
	
	local currentSpec = GetSpecialization();
	local sex = UnitSex("player");
	local desaturate = currentSpec and (currentSpec ~= SpellBookCoreAbilitiesFrame.selectedSpec);
	local specID, displayName = GetSpecializationInfo(SpellBookCoreAbilitiesFrame.selectedSpec, nil, nil, nil, sex);
	local draggable = false;
	if ( GetSpecialization() == SpellBookCoreAbilitiesFrame.selectedSpec ) then
		draggable = true;
	end
	
	SpellBookCoreAbilitiesFrame.SpecName:SetText(displayName);
	
	local abilityList = SPEC_CORE_ABILITY_DISPLAY[specID];
	if ( abilityList ) then
		for i=1, #abilityList do
			local name, subname = GetSpellInfo(abilityList[i]);
			local _, icon = GetSpellTexture(abilityList[i]);
			local button = SpellBook_GetCoreAbilityButton(i);
			local level = GetSpellLevelLearned(abilityList[i]);
			local showLevel = (level and level > UnitLevel("player"));
			local isPassive = IsPassiveSpell(abilityList[i]);
			local isKnown = IsSpellKnownOrOverridesKnown(abilityList[i]);
			
			button.spellID = abilityList[i];
			button.Name:SetText(name);
			button.InfoText:SetText(_G[SPEC_CORE_ABILITY_TEXT[specID].."_CORE_ABILITY_"..i]);

			button.iconTexture:SetTexture(icon);
			
			if ( not isKnown and IsCharacterNewlyBoosted() and not desaturate ) then
				button.ActiveTexture:Hide();
				button.RequiredLevel:SetText(BOOSTED_CHAR_SPELL_TEMPLOCK);
				button.iconTexture:SetAlpha(0.5);
				button.iconTexture:SetDesaturated(true);
				button.FutureTexture:Show();
				button.FutureTexture:SetDesaturated(false);
				button.EmptySlot:SetDesaturated(false);
				button.draggable = false;
			else
				button.iconTexture:SetDesaturated(showLevel or desaturate);
				button.iconTexture:SetAlpha(1);
				
				button.ActiveTexture:SetShown(not showLevel and not isPassive);
				button.ActiveTexture:SetDesaturated(desaturate);
				button.FutureTexture:SetShown(showLevel);
				button.FutureTexture:SetDesaturated(desaturate);
				button.EmptySlot:SetDesaturated(desaturate);
				button.draggable = draggable and not isPassive and not showLevel;
			
				if ( showLevel ) then
					button.RequiredLevel:SetFormattedText(SPELLBOOK_AVAILABLE_AT, level);
				else
					button.RequiredLevel:SetText("");
				end
		
				if ( showLevel or isPassive ) then
					button.highlightTexture:SetTexture("Interface\\Buttons\\UI-PassiveHighlight");
				else
					button.highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
				end
			end
	
			button:Show();
		end
	end
	for i = #abilityList + 1, #SpellBookCoreAbilitiesFrame.Abilities do
		SpellBook_GetCoreAbilityButton(i):Hide();
	end

	SpellBookPage1:SetDesaturated(desaturate);
	SpellBookPage2:SetDesaturated(desaturate);
end


-- *************************************************************************************

SpellBookFrame_HelpPlate = {
	FramePos = { x = 5,	y = -22 },
	FrameSize = { width = 580, height = 500	},
	[1] = { ButtonPos = { x = 250,	y = -50},	HighLightBox = { x = 65, y = -25, width = 460, height = 462 },	ToolTipDir = "DOWN",	ToolTipText = SPELLBOOK_HELP_1 },
	[2] = { ButtonPos = { x = 520,	y = -30 },	HighLightBox = { x = 540, y = -5, width = 46, height = 100 },	ToolTipDir = "LEFT",	ToolTipText = SPELLBOOK_HELP_2 },
	[3] = { ButtonPos = { x = 520,	y = -150},	HighLightBox = { x = 540, y = -125, width = 46, height = 200 },	ToolTipDir = "LEFT",	ToolTipText = SPELLBOOK_HELP_3, MinLevel = 10 },
}

ProfessionsFrame_HelpPlate = {
	FramePos = { x = 5,	y = -22 },
	FrameSize = { width = 545, height = 500	},
	[1] = { ButtonPos = { x = 150,	y = -110 }, HighLightBox = { x = 60, y = -35, width = 460, height = 195 }, ToolTipDir = "UP",	ToolTipText = PROFESSIONS_HELP_1 },
	[2] = { ButtonPos = { x = 150,	y = -325}, HighLightBox = { x = 60, y = -235, width = 460, height = 240 }, ToolTipDir = "UP",	ToolTipText = PROFESSIONS_HELP_2 },
}

CoreAbilitiesFrame_HelpPlate = {
	FramePos = { x = 5,	y = -22 },
	FrameSize = { width = 580, height = 500	},
	[1] = { ButtonPos = { x = 430,	y = -30}, HighLightBox = { x = 65, y = -15, width = 460, height = 472 }, ToolTipDir = "RIGHT",	ToolTipText = CORE_ABILITIES_HELP_1 },
}

function SpellBook_ToggleTutorial()
	local tutorial, helpPlate = SpellBookFrame_GetTutorialEnum();
	if ( helpPlate and not HelpPlate_IsShowing(helpPlate) and SpellBookFrame:IsShown()) then
		HelpPlate_Show( helpPlate, SpellBookFrame, SpellBookFrame.MainHelpButton );
		SetCVarBitfield( "closedInfoFrames", tutorial, true );
	else
		HelpPlate_Hide(true);
	end
end
