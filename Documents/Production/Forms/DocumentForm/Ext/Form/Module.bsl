
&AtClient
Procedure Cut_CutProfilesBefore(Command)
	
	If Object.FinishedGoods.Count() = 0 Or Object.Inventory.Count() = 0 Then
		// Nothing to cut
		Return;
	EndIf;
	
	Cut_CutProfilesBeforeAtServer();
	
EndProcedure

&AtServer
Procedure Cut_CutProfilesBeforeAtServer()
	
	FinishedGoodsTable = Object.FinishedGoods.Unload();
	MaterialsTable = Object.Inventory.Unload();
	NewMaterialTable = Object.Inventory.Unload();
	NewMaterialTable.Clear();
	
	For Each Row In FinishedGoodsTable Do
		RowStructure = NewRowStructure();
		RowStructure.Nomenclature   = Row.Nomenclature;
		RowStructure.Characteristic = Row.Characteristic;
		RowStructure.Quantity       = Row.Quantity;
		RowStructure.LengthRatio    = SmallBusinessServer.LengthRatio(Row.Characteristic);
		
		SearchStructure = New Structure("Nomenclature");
		FillPropertyValues(SearchStructure, RowStructure);
		
		MaterialRows = MaterialsTable.FindRows(SearchStructure);
		DeleteMaterialRows = New Array;
		For Each MalerialRow In MaterialRows Do
			MaterialRowStructure = NewRowStructure();
			MaterialRowStructure.Nomenclature   = MalerialRow.Nomenclature;
			MaterialRowStructure.Characteristic = MalerialRow.Characteristic;
			MaterialRowStructure.Quantity       = MalerialRow.Quantity;
			MaterialRowStructure.LengthRatio    = SmallBusinessServer.LengthRatio(MalerialRow.Characteristic);
			NewLength = RowStructure.LengthRatio - MaterialRowStructure.LengthRatio;
			If NewLength > 0 Then
				// This is nice. Cut it.
				If MaterialRowStructure.Quantity <= RowStructure.Quantity Then
					NewMaterialRow = NewMaterialTable.Add();
					FillPropertyValues(NewMaterialRow, MalerialRow);
					NewMaterialRow.CostPercentage = MaterialRowStructure.LengthRatio / RowStructure.LengthRatio;
					
					NewMaterialRow = NewMaterialTable.Add();
					FillPropertyValues(NewMaterialRow, MalerialRow,,"Characteristic");
					NewMaterialRow.Characteristic = CharacteristicOfLength(NewLength);
					NewMaterialRow.CostPercentage = NewLength / RowStructure.LengthRatio;
				EndIf;
				
				//DeleteMaterialRows.Add(MalerialRow.Index);
			EndIf;
			
		EndDo;
	EndDo;
	Object.Inventory.Load(NewMaterialTable);
	
EndProcedure

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

&AtServerNoContext
Function NewRowStructure()
	
	RowStructure = New Structure;
	RowStructure.Insert("Nomenclature");
	RowStructure.Insert("Characteristic");
	RowStructure.Insert("LengthRatio", 1);
	RowStructure.Insert("Quantity", 1);
	
	Return RowStructure;
	
EndFunction