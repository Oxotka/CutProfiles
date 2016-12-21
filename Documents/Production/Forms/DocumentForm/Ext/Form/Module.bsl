#Region FormCommandHandlers

&AtClient
Procedure Cut_CutProfilesBefore(Command)
	
	ClearMessages();
	
	If Object.FinishedGoods.Count() = 0 Or Object.Inventory.Count() = 0 Then
		// Nothing to cut
		Return;
	EndIf;
	
	Cut_CutProfilesBeforeAtServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure Cut_CutProfilesBeforeAtServer()
	
	If NOT CheckForCommand() Then
		Return;
	EndIf;
	
	FinishedGoodsSourceRow = Object.FinishedGoods[0];
	MaterialsSourceRow = Object.Inventory[0];
	
	If FinishedGoodsSourceRow.Nomenclature <> MaterialsSourceRow.Nomenclature Then
		TextMessage = StrTemplate(
			NStr("ru='Номенклатура %1 не найдена в таблице ""Материалы"".';en='Nomenclature %1 was not found in table ""Materials""'"),
			FinishedGoodsSourceRow.Nomenclature);
		CommonUseClientServer.MessageToUser(TextMessage);
		Return;
	EndIf;
	
	SourceLength   = SmallBusinessServer.LengthRatio(FinishedGoodsSourceRow.Characteristic);
	MaterialLength = SmallBusinessServer.LengthRatio(MaterialsSourceRow.Characteristic);
	NewLength      = SourceLength - MaterialLength;
	If NewLength <= 0 Then
		TextMessage = StrTemplate(
			NStr("ru='Не хватает длины профиля. Исходный профиль длиной %1 м. Новый профиль длиной %2 м.';en='Not enough length of the profile. The source profile has length of %1 m. New profile has length of %2 m.'"),
			SourceLength,
			MaterialLength);
		CommonUseClientServer.MessageToUser(TextMessage);
	Else
		// Source material
		MaterialsSourceRow.CostPercentage = (MaterialLength / SourceLength) * 100;
		
		// New material
		NewMaterialRow = Object.Inventory.Add();
		FillPropertyValues(NewMaterialRow, MaterialsSourceRow,,"Characteristic, CostPercentage");
		NewMaterialRow.Characteristic = CharacteristicOfLength(NewLength);
		NewMaterialRow.CostPercentage = (NewLength / SourceLength) * 100;
	EndIf;
	
EndProcedure

&AtServer
Function CheckForCommand()
	
	Check = True;
	// 1. Type of document
	If Object.TransactionType <> Enums.TransactionTypesProduction.Disassembly Then
		TextMessage = NStr("ru='Команда доступна только для вида операции ""Разборка"".';en='This command is only available for the type transaction ""Disassembly"".'");
		CommonUseClientServer.MessageToUser(TextMessage);
		Check = False;
		Return Check;
	EndIf;
	// 2. Count of row FinishedGoods
	If Object.FinishedGoods.Count() <> 1 Then
		TextMessage = NStr("ru='Команда доступна только если в табличной части ""Продукция"" одна строка.';en='This command is available only if in table ""Finished goods"" has one line'");
		CommonUseClientServer.MessageToUser(TextMessage);
		Check = False;
	EndIf;
	// 3. Count of row Inventory
	If Object.Inventory.Count() <> 1 Then
		TextMessage = NStr("ru='Команда доступна только если в табличной части ""Материалы"" одна строка.';en='This command is available only if in table ""Materials"" has one line'");
		CommonUseClientServer.MessageToUser(TextMessage);
		Check = False;
	EndIf;
	// 4. Quantity in tables
	FinishedGoodsQuantity = Object.FinishedGoods.Total("Quantity");
	InventoryQuantity = Object.Inventory.Total("Quantity");
	If FinishedGoodsQuantity <> InventoryQuantity Then
		TextMessage = NStr("ru='Не совпадает количество в табличных частях.';en='Tables has different quantity of products'");
		CommonUseClientServer.MessageToUser(TextMessage);
		Check = False;
	EndIf;
	
	Return Check;
	
EndFunction

&AtServerNoContext
Function CharacteristicOfLength(Length)
	
	Query = New Query;
	Query.SetParameter("Length", Length);
	Query.SetParameter("Property", Constants.CharacteristicLength.Get());
	Query.Text = 
	"Select 
	|	NomenclatureCharacteristicsAdditionalAttributes.Ref
	|From
	|	Catalog.NomenclatureCharacteristics.AdditionalAttributes as NomenclatureCharacteristicsAdditionalAttributes
	|Where
	|	NomenclatureCharacteristicsAdditionalAttributes.Value = &Length
	|	and NomenclatureCharacteristicsAdditionalAttributes.Property = &Property";
	Select = Query.Execute().Select();
	If Select.Next() Then
		Return Select.Ref;
	Else
		TextMessage = StrTemplate(NStr("ru='Не найдена характеристика с длиной %1.';en='Characteristic with length %1 is not found.'"), Length);
		CommonUseClientServer.MessageToUser(TextMessage);
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion