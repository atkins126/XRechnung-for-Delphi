{
License XRechnung-for-Delphi

Copyright (C) 2024 Landrix Software GmbH & Co. KG
Sven Harazim, info@landrix.de
Version 3.0.1

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
}

unit intf.XRechnung_3_0;

interface

uses
  System.SysUtils,System.Classes,System.Types
  ,System.StrUtils,System.Generics.Collections
  ,Xml.xmldom,Xml.XMLDoc,Xml.XMLIntf,Xml.XMLSchema
  ,Xml.Win.msxmldom, Winapi.MSXMLIntf, Winapi.msxml
  ,intf.Invoice
  ,intf.XRechnungHelper
  ;

type
  TXRechnungInvoiceAdapter301 = class
  private
    class procedure InternalReadPaymentTerms(_Invoice: TInvoice;
      _PaymentTermsText: String); static;
  public
    class procedure SaveDocumentUNCEFACT(_Invoice: TInvoice;_Xml : IXMLDocument);
    class procedure SaveDocumentUBL(_Invoice: TInvoice;_Xml : IXMLDocument);
    class function LoadDocumentUNCEFACT(_Invoice: TInvoice;_Xml : IXMLDocument; out _Error : String) : Boolean;
    class function LoadDocumentUBL(_Invoice: TInvoice;_Xml : IXMLDocument; out _Error : String) : Boolean;
  end;

implementation

uses
  intf.XRechnung;

{ TXRechnungInvoiceAdapter301 }

class procedure TXRechnungInvoiceAdapter301.InternalReadPaymentTerms(
  _Invoice: TInvoice; _PaymentTermsText: String);
var
  paymentTerms,paymentTerm : TArray<String>;
begin
  if _PaymentTermsText = '' then
    exit;
  if Pos('#SKONTO#',_PaymentTermsText) = 0 then
  begin
    _Invoice.PaymentTermsType := iptt_Net;
    _Invoice.PaymentTermNetNote := _PaymentTermsText;
  end else
  if (Pos('#SKONTO#',_PaymentTermsText) = 1) and (Pos(#10,Trim(_PaymentTermsText)) > 1) then //zweimal Skonto
  begin
    _Invoice.PaymentTermsType := iptt_CashDiscount2;
    paymentTerms := _PaymentTermsText.Split([#10]);
    if (Length(paymentTerms) >= 2) then if (Pos('#SKONTO#',paymentTerms[1]) = 1) then
    begin
      paymentTerm := paymentTerms[1].Split(['#']); //0 Leer, 1 Skonto, 2 Tage, 3 Prozent, 4 Leer o. Basiswert
      if (Length(paymentTerm) >= 5) then
      begin
        Delete(paymentTerm[2],1,5);
        _Invoice.PaymentTermCashDiscount2Days := StrToIntDef(paymentTerm[2],0);
        Delete(paymentTerm[3],1,8);
        _Invoice.PaymentTermCashDiscount2Percent := TXRechnungHelper.FloatFromStr(paymentTerm[3]);
        if Pos('BASISBETRAG=',paymentTerm[4])=1 then
        begin
          Delete(paymentTerm[4],1,12);
          _Invoice.PaymentTermCashDiscount2Base := TXRechnungHelper.AmountFromStr(paymentTerm[4]);
        end
        else
          _Invoice.PaymentTermCashDiscount2Base := 0;
      end;
    end else
      _Invoice.PaymentTermsType := iptt_CashDiscount1;
    if (Length(paymentTerms) >= 1) then if (Pos('#SKONTO#',paymentTerms[0]) = 1) then
    begin
      paymentTerm := paymentTerms[0].Split(['#']); //0 Leer, 1 Skonto, 2 Tage, 3 Prozent, 4 Leer o. Basiswert
      if (Length(paymentTerm) >= 5) then
      begin
        Delete(paymentTerm[2],1,5);
        _Invoice.PaymentTermCashDiscount1Days := StrToIntDef(paymentTerm[2],0);
        Delete(paymentTerm[3],1,8);
        _Invoice.PaymentTermCashDiscount1Percent := TXRechnungHelper.FloatFromStr(paymentTerm[3]);
        if Pos('BASISBETRAG=',paymentTerm[4])=1 then
        begin
          Delete(paymentTerm[4],1,12);
          _Invoice.PaymentTermCashDiscount1Base := TXRechnungHelper.AmountFromStr(paymentTerm[4]);
        end
        else
          _Invoice.PaymentTermCashDiscount1Base := 0;
      end;
    end else
      _Invoice.PaymentTermsType := iptt_Net;
  end else
  if Pos('#SKONTO#',_PaymentTermsText) = 1 then //einmal Skonto
  begin
    _Invoice.PaymentTermsType := iptt_CashDiscount1;
    paymentTerm := _PaymentTermsText.Split(['#']); //0 Leer, 1 Skonto, 2 Tage, 3 Prozent, 4 Leer o. Basiswert
    if (Length(paymentTerm) >= 5) then
    begin
      Delete(paymentTerm[2],1,5);
      _Invoice.PaymentTermCashDiscount1Days := StrToIntDef(paymentTerm[2],0);
      Delete(paymentTerm[3],1,8);
      _Invoice.PaymentTermCashDiscount1Percent := TXRechnungHelper.FloatFromStr(paymentTerm[3]);
      if Pos('BASISBETRAG=',paymentTerm[4])=1 then
      begin
        Delete(paymentTerm[4],1,12);
        _Invoice.PaymentTermCashDiscount1Base := TXRechnungHelper.AmountFromStr(paymentTerm[4]);
      end
      else
        _Invoice.PaymentTermCashDiscount1Base := 0;
    end;
  end else
  begin
    _Invoice.PaymentTermsType := iptt_None;
    _Invoice.PaymentTermNetNote := _PaymentTermsText;
  end;
end;

class function TXRechnungInvoiceAdapter301.LoadDocumentUBL(_Invoice: TInvoice;
  _Xml: IXMLDocument; out _Error : String) : Boolean;
var
  xml : IXMLDOMDocument2;
  node,node2 : IXMLDOMNode;
  nodes : IXMLDOMNodeList;
  i : Integer;

  procedure InternalReadInvoiceLine(_Invoiceline : TInvoiceLine; _Node : IXMLDOMNode);
  var
    node : IXMLDOMNode;
    nodes : IXMLDOMNodeList;
    i : Integer;
  begin
    _Invoiceline.ID := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cbc:ID');
    _Invoiceline.Note := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cbc:Note');
    if TXRechnungXMLHelper.SelectNode(_Node,'.//cbc:InvoicedQuantity',node) then
    begin
      _Invoiceline.UnitCode := TXRechnungHelper.InvoiceUnitCodeFromStr(TXRechnungXMLHelper.SelectAttributeText(node,'unitCode'));
      _Invoiceline.Quantity := TXRechnungHelper.QuantityFromStr(node.text);
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//cbc:LineExtensionAmount',node) then
      _Invoiceline.LineAmount := TXRechnungHelper.AmountFromStr(node.text);
    if TXRechnungXMLHelper.SelectNodes(_Node,'cac:AllowanceCharge',nodes) then
    for i := 0 to nodes.length-1 do
    with _Invoiceline.AllowanceCharges.AddAllowanceCharge do
    begin
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:ChargeIndicator',node) then
        ChargeIndicator := StrToBoolDef(node.text,false);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:AllowanceChargeReasonCode',node) then
      begin
        if ChargeIndicator then
          ReasonCodeCharge := TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeFromStr(node.text)
        else
          ReasonCodeAllowance := TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeFromStr(node.text);
      end;
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:AllowanceChargeReason',node) then
        Reason := node.text;
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:MultiplierFactorNumeric',node) then
        MultiplierFactorNumeric := TXRechnungHelper.FloatFromStr(node.text);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:Amount',node) then
        Amount := TXRechnungHelper.AmountFromStr(node.text);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:BaseAmount',node) then
        BaseAmount := TXRechnungHelper.AmountFromStr(node.text);
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//cac:Item',node) then
    begin
      _Invoiceline.Description := TXRechnungXMLHelper.SelectNodeText(node,'.//cbc:Description');
      _Invoiceline.Name := TXRechnungXMLHelper.SelectNodeText(node,'.//cbc:Name');
      _Invoiceline.SellersItemIdentification := TXRechnungXMLHelper.SelectNodeText(node,'.//cac:SellersItemIdentification/cbc:ID');
      if (TXRechnungXMLHelper.SelectNode(node,'.//cac:StandardItemIdentification/cbc:ID',node2)) then
      if (TXRechnungXMLHelper.SelectAttributeText(node2,'schemeID') = '0160') then
        _Invoiceline.GlobalID_EAN_GTIN := node2.text;
      _Invoiceline.TaxCategory := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//cac:ClassifiedTaxCategory/cbc:ID'));
      _Invoiceline.TaxPercent := TXRechnungHelper.PercentageFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//cac:ClassifiedTaxCategory/cbc:Percent'));
      //VAT := TXRechnungXMLHelper.SelectNodeText(node,'.//cac:TaxScheme/cbc:ID');
    end;
    _Invoiceline.NetPriceAmount := TXRechnungHelper.UnitPriceAmountFromStr(TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:Price/cbc:PriceAmount'));
    if TXRechnungXMLHelper.SelectNode(_Node,'.//cac:Price/cbc:BaseQuantity',node) then
    begin
      _Invoiceline.BaseQuantityUnitCode := TXRechnungHelper.InvoiceUnitCodeFromStr(TXRechnungXMLHelper.SelectAttributeText(node,'unitCode'));
      _Invoiceline.BaseQuantity := TXRechnungHelper.FloatFromStr(node.text);
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//cac:Price/cac:AllowanceCharge',node) then
    begin
      _Invoiceline.GrossPriceAmount := TXRechnungHelper.UnitPriceAmountFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//cbc:BaseAmount'));
      _Invoiceline.DiscountOnTheGrossPrice := TXRechnungHelper.UnitPriceAmountFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//cbc:Amount'));
    end;
    if TXRechnungXMLHelper.SelectNodes(_Node,'.//cac:SubInvoiceLine',nodes) then
    for i := 0 to nodes.length-1 do
      InternalReadInvoiceLine(_InvoiceLine.SubInvoiceLines.AddInvoiceLine,nodes.item[i]);
  end;

  procedure InternalReadParty(var _Party : TInvoiceAccountingParty; _Node : IXMLDOMNode);
  var
    node : IXMLDOMNode;
    nodes : IXMLDOMNodeList;
    i : Integer;
  begin
    if TXRechnungXMLHelper.SelectNode(_Node,'.//cbc:EndpointID',node) then
    if (TXRechnungXMLHelper.SelectAttributeText(node,'schemeID') = 'EM') then
      _Party.ElectronicAddressSellerBuyer := node.text;
    if TXRechnungXMLHelper.SelectNodes(_Node,'.//cac:PartyIdentification',nodes) then
    for i := 0 to nodes.length-1 do
    if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:ID',node) then
    begin
      if SameText(TXRechnungXMLHelper.SelectAttributeText(node,'schemeID'),'0088') then
        _Party.IdentifierSellerBuyer := node.text
      else
      if SameText(TXRechnungXMLHelper.SelectAttributeText(node,'schemeID'),'SEPA') then
        _Party.BankAssignedCreditorIdentifier := node.text;
    end;
    _Party.Name := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PartyName/cbc:Name');
    _Party.Address.StreetName := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cbc:StreetName');
    _Party.Address.AdditionalStreetName := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cbc:AdditionalStreetName');
    _Party.Address.City := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cbc:CityName');
    _Party.Address.PostalZone := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cbc:PostalZone');
    _Party.Address.CountrySubentity := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cbc:CountrySubentity');
    _Party.Address.AddressLine := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cac:AddressLine/cbc:Line');
    _Party.Address.CountryCode := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PostalAddress/cac:Country/cbc:IdentificationCode');
    if TXRechnungXMLHelper.SelectNodes(_Node,'.//cac:PartyTaxScheme',nodes) then
    for i := 0 to nodes.length-1 do
    begin
      if TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cac:TaxScheme/cbc:ID') = 'VAT' then
        _Party.VATCompanyID := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cbc:CompanyID')
      else
      if TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cac:TaxScheme/cbc:ID') = 'FC' then
        _Party.VATCompanyNumber := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cbc:CompanyID');
    end;
    _Party.RegistrationName := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PartyLegalEntity/cbc:RegistrationName');
    _Party.CompanyID := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PartyLegalEntity/cbc:CompanyID');
    _Party.AdditionalLegalInformationSeller := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:PartyLegalEntity/cbc:CompanyLegalForm');
    _Party.ContactName := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:Contact/cbc:Name');
    _Party.ContactTelephone := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:Contact/cbc:Telephone');
    _Party.ContactElectronicMail := TXRechnungXMLHelper.SelectNodeText(_Node,'.//cac:Contact/cbc:ElectronicMail');
  end;

begin
  Result := false;
  _Error := '';
  try
    xml := TXRechnungXMLHelper.PrepareDocumentForXPathQuerys(_Xml);
    if TXRechnungXMLHelper.SelectNode(xml,'//cbc:ID',node) then
      _Invoice.InvoiceNumber := node.Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cbc:IssueDate',node) then
      _Invoice.InvoiceIssueDate := TXRechnungHelper.DateFromStrUBLFormat(node.Text);
    if TXRechnungXMLHelper.SelectNode(xml,'//cbc:DueDate',node) then
      _Invoice.InvoiceDueDate := TXRechnungHelper.DateFromStrUBLFormat(node.Text);
    if TXRechnungXMLHelper.SelectNode(xml,'//cbc:InvoiceTypeCode',node) then
      _Invoice.InvoiceTypeCode := TXRechnungHelper.InvoiceTypeCodeFromStr(node.Text);
    if TXRechnungXMLHelper.SelectNodes(xml,'//ubl:Invoice/cbc:Note',nodes) then
    for i := 0  to nodes.length-1 do
      _Invoice.Notes.AddNote.Content := nodes.item[i].Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cbc:DocumentCurrencyCode',node) then
      _Invoice.InvoiceCurrencyCode := node.Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cbc:BuyerReference',node) then
      _Invoice.BuyerReference := node.Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:InvoicePeriod',node) then
    begin
      _Invoice.InvoicePeriodStartDate := TXRechnungHelper.DateFromStrUBLFormat(TXRechnungXMLHelper.SelectNodeText(node,'//cbc:StartDate'));
      _Invoice.InvoicePeriodEndDate := TXRechnungHelper.DateFromStrUBLFormat(TXRechnungXMLHelper.SelectNodeText(node,'//cbc:EndDate'));
    end;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:OrderReference/cbc:ID',node) then
      _Invoice.PurchaseOrderReference := node.Text;
    if TXRechnungXMLHelper.SelectNodes(xml,'//cac:BillingReference/cac:InvoiceDocumentReference',nodes) then
    for i := 0  to nodes.length-1 do
    with _Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference do
    begin
      ID := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cbc:ID');
      IssueDate := TXRechnungHelper.DateFromStrUBLFormat(TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cbc:IssueDate'));
    end;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:DespatchDocumentReference/cbc:ID',node) then
      _Invoice.DeliveryReceiptNumber := node.Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:ContractDocumentReference/cbc:ID',node) then
      _Invoice.ContractDocumentReference := node.Text;
    if TXRechnungXMLHelper.SelectNodes(xml,'//cac:AdditionalDocumentReference',nodes) then
    for i := 0  to nodes.length-1 do
    with _Invoice.Attachments.AddAttachment(iat_application_None) do
    begin
      ID := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cbc:ID');
      DocumentDescription := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//cbc:DocumentDescription');
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cac:Attachment',node) then
      begin
        if TXRechnungXMLHelper.FindNode(node,'.//cac:ExternalReference/cbc:URI') then
          ExternalReference := TXRechnungXMLHelper.SelectNodeText(node,'.//cac:ExternalReference/cbc:URI')
        else
        if TXRechnungXMLHelper.SelectNode(node,'.//cbc:EmbeddedDocumentBinaryObject',node2) then
        begin
          AttachmentType := TXRechnungHelper.InvoiceAttachmentTypeFromStr(TXRechnungXMLHelper.SelectAttributeText(node2,'mimeCode'));
          Filename := TXRechnungXMLHelper.SelectAttributeText(node2,'filename');
          SetDataFromBase64(node2.Text);
        end;
      end;
    end;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:ProjectReference/cbc:ID',node) then
      _Invoice.ProjectReference := node.Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:AccountingSupplierParty/cac:Party',node) then
      InternalReadParty(_Invoice.AccountingSupplierParty,node);
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:AccountingCustomerParty/cac:Party',node) then
      InternalReadParty(_Invoice.AccountingCustomerParty,node);
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:Delivery',node) then
    begin
      if TXRechnungXMLHelper.SelectNode(node,'.//cbc:ActualDeliveryDate',node2) then
        _Invoice.DeliveryInformation.ActualDeliveryDate := TXRechnungHelper.DateFromStrUBLFormat(node2.text);
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cbc:StreetName',node2) then
        _Invoice.DeliveryInformation.Address.StreetName := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cbc:AdditionalStreetName',node2) then
        _Invoice.DeliveryInformation.Address.AdditionalStreetName := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cbc:CityName',node2) then
        _Invoice.DeliveryInformation.Address.City := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cbc:PostalZone',node2) then
        _Invoice.DeliveryInformation.Address.PostalZone := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cbc:CountrySubentity',node2) then
        _Invoice.DeliveryInformation.Address.CountrySubentity := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cac:AddressLine/cbc:Line',node2) then
        _Invoice.DeliveryInformation.Address.AddressLine := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryLocation/cac:Address/cac:Country/cbc:IdentificationCode',node2) then
        _Invoice.DeliveryInformation.Address.CountryCode := node2.text;
      if TXRechnungXMLHelper.SelectNode(node,'.//cac:DeliveryParty/cac:PartyName/cbc:Name',node2) then
        _Invoice.DeliveryInformation.Name := node2.text;
    end;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cbc:PaymentMeansCode',node) then
      _Invoice.PaymentMeansCode := TXRechnungHelper.InvoicePaymentMeansCodeFromStr(node.text);
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cbc:PaymentID',node) then
      _Invoice.PaymentID := node.text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cac:PayeeFinancialAccount/cbc:ID',node) then
      _Invoice.PaymentFinancialAccount := node.text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cac:PayeeFinancialAccount/cbc:Name',node) then
      _Invoice.PaymentFinancialAccountName := node.text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cac:PayeeFinancialAccount/cac:FinancialInstitutionBranch/cbc:ID',node) then
      _Invoice.PaymentFinancialInstitutionBranch := node.text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cac:PaymentMandate/cbc:ID',node) then
      _Invoice.PaymentMandateID := node.text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentMeans/cac:PaymentMandate/cac:PayerFinancialAccount/cbc:ID',node) then
      _Invoice.PaymentFinancialAccount := node.text;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:PaymentTerms/cbc:Note',node) then
      TXRechnungInvoiceAdapter301.InternalReadPaymentTerms(_Invoice,node.text);

    if TXRechnungXMLHelper.SelectNodes(xml,'//ubl:Invoice/cac:AllowanceCharge',nodes) then
    for i := 0 to nodes.length-1 do
    with _Invoice.AllowanceCharges.AddAllowanceCharge do
    begin
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:ChargeIndicator',node) then
        ChargeIndicator := StrToBoolDef(node.text,false);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:AllowanceChargeReasonCode',node) then
      begin
        if ChargeIndicator then
          ReasonCodeCharge := TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeFromStr(node.text)
        else
          ReasonCodeAllowance := TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeFromStr(node.text);
      end;
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:AllowanceChargeReason',node) then
        Reason := node.text;
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:MultiplierFactorNumeric',node) then
        MultiplierFactorNumeric := TXRechnungHelper.FloatFromStr(node.text);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:Amount',node) then
        Amount := TXRechnungHelper.AmountFromStr(node.text);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cbc:BaseAmount',node) then
        BaseAmount := TXRechnungHelper.AmountFromStr(node.text);

      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cac:TaxCategory/cbc:ID',node) then
        TaxCategory := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeFromStr(node.text);
      if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cac:TaxCategory/cbc:Percent',node) then
        TaxPercent := TXRechnungHelper.PercentageFromStr(node.text);
      //if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//cac:TaxCategory/cac:TaxScheme/cbc:ID',node) then
      //  VAT := node.text Ausgabe VAT fest programmiert
    end;
    if TXRechnungXMLHelper.SelectNode(xml,'//cac:TaxTotal',node) then
    begin
      if TXRechnungXMLHelper.SelectNode(node,'.//cbc:TaxAmount',node2) then
      begin
        _Invoice.TaxCurrencyCode := TXRechnungXMLHelper.SelectAttributeText(node2,'currencyID');
        _Invoice.TaxAmountTotal := TXRechnungHelper.AmountFromStr(node2.text);
      end;
      if TXRechnungXMLHelper.SelectNodes(node,'.//cac:TaxSubtotal',nodes) then
      for i := 0  to nodes.length-1 do
      begin
        SetLength(_Invoice.TaxAmountSubtotals,Length(_Invoice.TaxAmountSubtotals)+1);
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//cbc:TaxAmount'));
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxExemptionReason := TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//cac:TaxCategory/cbc:TaxExemptionReason');
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxableAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//cbc:TaxableAmount'));
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxCategory := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//cac:TaxCategory/cbc:ID'));
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxPercent := TXRechnungHelper.PercentageFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//cac:TaxCategory/cbc:Percent'));
        //TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//cac:TaxCategory/cac:TaxScheme/cbc:ID') Ausgabe VAT fest programmiert
      end;
    end;

    _Invoice.LineAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:LineExtensionAmount'));
    _Invoice.TaxExclusiveAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount'));
    _Invoice.TaxInclusiveAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount'));
    _Invoice.AllowanceTotalAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:AllowanceTotalAmount'));
    _Invoice.ChargeTotalAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:ChargeTotalAmount'));
    _Invoice.PrepaidAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:PrepaidAmount'));
    _Invoice.PayableAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(xml,'//cac:LegalMonetaryTotal/cbc:PayableAmount'));

    if TXRechnungXMLHelper.SelectNodes(xml,'.//cac:InvoiceLine',nodes) then
    for i := 0 to nodes.length-1 do
      InternalReadInvoiceLine(_Invoice.InvoiceLines.AddInvoiceLine,nodes[i]);

    Result := true;
  except
    on E:Exception do _Error := E.ClassName+' '+E.Message;
  end;
end;

class function TXRechnungInvoiceAdapter301.LoadDocumentUNCEFACT(_Invoice: TInvoice;
  _Xml: IXMLDocument; out _Error : String) : Boolean;
var
  xml : IXMLDOMDocument2;
  node,node2,node3,node4,nodeSupplyChainTradeTransaction,
  nodeApplicableHeaderTradeAgreement : IXMLDOMNode;
  nodes : IXMLDOMNodeList;
  i : Integer;

  procedure InternalReadInvoiceLine(_Invoiceline : TInvoiceLine; _Node : IXMLDOMNode);
  var
    node,node2,node3 : IXMLDOMNode;
    nodes : IXMLDOMNodeList;
    i : Integer;
  begin
    if TXRechnungXMLHelper.SelectNode(_Node,'.//ram:AssociatedDocumentLineDocument',node2) then
    begin
      _Invoiceline.ID := TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:LineID');
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:IncludedNote',node) then
        _Invoiceline.Note := TXRechnungXMLHelper.SelectNodeText(node,'.//ram:Content');
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//ram:SpecifiedTradeProduct',node2) then
    begin
      if (TXRechnungXMLHelper.SelectNode(node2,'.//ram:GlobalID',node3)) then
      if (TXRechnungXMLHelper.SelectAttributeText(node3,'schemeID') = '0160') then
        _Invoiceline.GlobalID_EAN_GTIN := node3.text;
      _Invoiceline.SellersItemIdentification := TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:SellerAssignedID');
      _Invoiceline.Name := TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:Name');
      _Invoiceline.Description := TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:Description');
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//ram:SpecifiedLineTradeAgreement',node2) then
    begin
//        <ram:BuyerOrderReferencedDocument>
//            <ram:LineID>6171175.1</ram:LineID>
//        </ram:BuyerOrderReferencedDocument>
//        <cac:OrderLineReference>
//            <cbc:LineID>6171175.1</cbc:LineID>
//        </cac:OrderLineReference>
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:GrossPriceProductTradePrice',node3) then
      begin
        _Invoiceline.GrossPriceAmount := TXRechnungHelper.UnitPriceAmountFromStr(TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:ChargeAmount'));
        _Invoiceline.DiscountOnTheGrossPrice := TXRechnungHelper.UnitPriceAmountFromStr(TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:AppliedTradeAllowanceCharge/ram:ActualAmount'));
      end;
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:NetPriceProductTradePrice',node3) then
      begin
        _Invoiceline.NetPriceAmount := TXRechnungHelper.UnitPriceAmountFromStr(TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:ChargeAmount'));
        if TXRechnungXMLHelper.SelectNode(node3,'.//ram:BasisQuantity',node) then
        begin
          _Invoiceline.BaseQuantityUnitCode := TXRechnungHelper.InvoiceUnitCodeFromStr(TXRechnungXMLHelper.SelectAttributeText(node,'unitCode'));
          _Invoiceline.BaseQuantity := TXRechnungHelper.FloatFromStr(node.text);
        end;
      end;
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//ram:SpecifiedLineTradeDelivery',node2) then
    if TXRechnungXMLHelper.SelectNode(node2,'.//ram:BilledQuantity',node) then
    begin
      _Invoiceline.UnitCode := TXRechnungHelper.InvoiceUnitCodeFromStr(TXRechnungXMLHelper.SelectAttributeText(node,'unitCode'));
      _Invoiceline.Quantity := TXRechnungHelper.QuantityFromStr(node.text);
    end;
    if TXRechnungXMLHelper.SelectNode(_Node,'.//ram:SpecifiedLineTradeSettlement',node2) then
    begin
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:ApplicableTradeTax',node) then
      begin
        _Invoiceline.TaxCategory := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//ram:CategoryCode'));
        _Invoiceline.TaxPercent := TXRechnungHelper.PercentageFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//ram:RateApplicablePercent'));
      end;
      if TXRechnungXMLHelper.SelectNodes(node2,'.//ram:SpecifiedTradeAllowanceCharge',nodes) then
      for i := 0 to nodes.length-1 do
      with _Invoiceline.AllowanceCharges.AddAllowanceCharge do
      begin
        if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ChargeIndicator/udt:Indicator',node) then
          ChargeIndicator := StrToBoolDef(node.text,false);
        MultiplierFactorNumeric := TXRechnungHelper.FloatFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:CalculationPercent'));
        BaseAmount  := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:BasisAmount'));
        Amount  := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ActualAmount'));
        if ChargeIndicator then
          ReasonCodeCharge := TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ReasonCode'))
        else
          ReasonCodeAllowance := TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ReasonCode'));
        Reason := TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:Reason');
      end;
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:SpecifiedTradeSettlementLineMonetarySummation',node) then
      begin
        _Invoiceline.LineAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node,'.//ram:LineTotalAmount'));
      end;
    end;
    if TXRechnungXMLHelper.SelectNodes(_Node,'.//ram:IncludedSupplyChainTradeLineItem',nodes) then
    for i := 0 to nodes.length-1 do
      InternalReadInvoiceLine(_InvoiceLine.SubInvoiceLines.AddInvoiceLine,nodes.item[i]);
  end;

begin
  Result := false;
  _Error := '';
  try
    xml := TXRechnungXMLHelper.PrepareDocumentForXPathQuerys(_Xml);
    if TXRechnungXMLHelper.SelectNode(xml,'//*[local-name()="ExchangedDocument"]/ram:ID',node) then
      _Invoice.InvoiceNumber := node.Text;
    if TXRechnungXMLHelper.SelectNode(xml,'//*[local-name()="ExchangedDocument"]/ram:IssueDateTime/udt:DateTimeString',node) then
      _Invoice.InvoiceIssueDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(node.Text);
    if TXRechnungXMLHelper.SelectNode(xml,'//*[local-name()="ExchangedDocument"]/ram:TypeCode',node) then
      _Invoice.InvoiceTypeCode := TXRechnungHelper.InvoiceTypeCodeFromStr(node.Text);
    if TXRechnungXMLHelper.SelectNodes(xml,'//*[local-name()="ExchangedDocument"]/ram:IncludedNote',nodes) then
    for i := 0 to nodes.length-1 do
      _Invoice.Notes.AddNote.Content := TXRechnungXMLHelper.SelectNodeText(nodes[i], './/ram:Content');

    if not TXRechnungXMLHelper.SelectNode(xml,'//*[local-name()="SupplyChainTradeTransaction"]',nodeSupplyChainTradeTransaction) then
      exit;

    if TXRechnungXMLHelper.SelectNodes(xml,'.//*[local-name()="SupplyChainTradeTransaction"]/ram:IncludedSupplyChainTradeLineItem',nodes) then
    for i := 0 to nodes.length-1 do
      InternalReadInvoiceLine(_Invoice.InvoiceLines.AddInvoiceLine,nodes[i]);

    if TXRechnungXMLHelper.SelectNode(nodeSupplyChainTradeTransaction,'.//ram:ApplicableHeaderTradeAgreement',nodeApplicableHeaderTradeAgreement) then
    begin
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:BuyerReference',node) then
        _Invoice.BuyerReference := node.text;

      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:SellerTradeParty',node2) then
      begin
        if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:SellerTradeParty/ram:ID',node) then
          _Invoice.AccountingSupplierParty.IdentifierSellerBuyer := node.text;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:Name',node) then
          _Invoice.AccountingSupplierParty.RegistrationName := node.text;
        _Invoice.AccountingSupplierParty.AdditionalLegalInformationSeller := TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:Description');

        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:SpecifiedLegalOrganization',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:ID',node) then
            _Invoice.AccountingSupplierParty.CompanyID := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:TradingBusinessName',node) then
            _Invoice.AccountingSupplierParty.Name := node.text;
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:DefinedTradeContact',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:PersonName',node) then
            _Invoice.AccountingSupplierParty.ContactName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:TelephoneUniversalCommunication',node4) then
          if TXRechnungXMLHelper.SelectNode(node4,'.//ram:CompleteNumber',node) then
            _Invoice.AccountingSupplierParty.ContactTelephone := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:EmailURIUniversalCommunication',node4) then
          if TXRechnungXMLHelper.SelectNode(node4,'.//ram:URIID',node) then
            _Invoice.AccountingSupplierParty.ContactElectronicMail := node.text;
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:PostalTradeAddress',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:PostcodeCode',node) then
            _Invoice.AccountingSupplierParty.Address.PostalZone := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineOne',node) then
            _Invoice.AccountingSupplierParty.Address.StreetName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineTwo',node) then
            _Invoice.AccountingSupplierParty.Address.AdditionalStreetName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineThree',node) then
            _Invoice.AccountingSupplierParty.Address.AddressLine := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CityName',node) then
            _Invoice.AccountingSupplierParty.Address.City := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CountryID',node) then
            _Invoice.AccountingSupplierParty.Address.CountryCode := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CountrySubDivisionName',node) then
            _Invoice.AccountingSupplierParty.Address.CountrySubentity := node.text;
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:URIUniversalCommunication',node3) then
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:URIID',node) then
            _Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyer := node.text;
        if TXRechnungXMLHelper.SelectNodes(node2,'.//ram:SpecifiedTaxRegistration',nodes) then
        for i := 0  to nodes.length-1 do
        if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ID',node3) then
        begin
          if SameText(TXRechnungXMLHelper.SelectAttributeText(node3,'schemeID'),'VA') then
            _Invoice.AccountingSupplierParty.VATCompanyID := node3.text
          else
          if SameText(TXRechnungXMLHelper.SelectAttributeText(node3,'schemeID'),'FC') then
            _Invoice.AccountingSupplierParty.VATCompanyNumber := node3.text;
        end;
      end;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:BuyerTradeParty',node2) then
      begin
        if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:BuyerTradeParty/ram:ID',node) then
          _Invoice.AccountingCustomerParty.IdentifierSellerBuyer := node.text;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:Name',node) then
          _Invoice.AccountingCustomerParty.RegistrationName := node.text;

        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:SpecifiedLegalOrganization',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:ID',node) then
            _Invoice.AccountingCustomerParty.CompanyID := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:TradingBusinessName',node) then
            _Invoice.AccountingCustomerParty.Name := node.text;
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:DefinedTradeContact',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:PersonName',node) then
            _Invoice.AccountingCustomerParty.ContactName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:TelephoneUniversalCommunication',node4) then
          if TXRechnungXMLHelper.SelectNode(node4,'.//ram:CompleteNumber',node) then
            _Invoice.AccountingCustomerParty.ContactTelephone := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:EmailURIUniversalCommunication',node4) then
          if TXRechnungXMLHelper.SelectNode(node4,'.//ram:URIID',node) then
            _Invoice.AccountingCustomerParty.ContactElectronicMail := node.text;
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:PostalTradeAddress',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:PostcodeCode',node) then
            _Invoice.AccountingCustomerParty.Address.PostalZone := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineOne',node) then
            _Invoice.AccountingCustomerParty.Address.StreetName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineTwo',node) then
            _Invoice.AccountingCustomerParty.Address.AdditionalStreetName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineThree',node) then
            _Invoice.AccountingCustomerParty.Address.AddressLine := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CityName',node) then
            _Invoice.AccountingCustomerParty.Address.City := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CountryID',node) then
            _Invoice.AccountingCustomerParty.Address.CountryCode := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CountrySubDivisionName',node) then
            _Invoice.AccountingCustomerParty.Address.CountrySubentity := node.text;
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:URIUniversalCommunication',node3) then
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:URIID',node) then
            _Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyer := node.text;

        if TXRechnungXMLHelper.SelectNodes(node2,'.//ram:SpecifiedTaxRegistration',nodes) then
        for i := 0  to nodes.length-1 do
        if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ID',node3) then
        begin
          if SameText(TXRechnungXMLHelper.SelectAttributeText(node3,'schemeID'),'VA') then
            _Invoice.AccountingCustomerParty.VATCompanyID := node3.text
          else
          if SameText(TXRechnungXMLHelper.SelectAttributeText(node3,'schemeID'),'FC') then
            _Invoice.AccountingCustomerParty.VATCompanyNumber := node3.text;
        end;
      end;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:SellerOrderReferencedDocument',node2) then
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:IssuerAssignedID',node) then
        _Invoice.SellerOrderReference := node.text;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:BuyerOrderReferencedDocument',node2) then
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:IssuerAssignedID',node) then
        _Invoice.PurchaseOrderReference := node.text;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:ContractReferencedDocument',node2) then
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:IssuerAssignedID',node) then
        _Invoice.ContractDocumentReference := node.text;

      if TXRechnungXMLHelper.SelectNodes(nodeApplicableHeaderTradeAgreement,'.//ram:AdditionalReferencedDocument',nodes) then
      for i := 0  to nodes.length-1 do
      with _Invoice.Attachments.AddAttachment(iat_application_None) do
      begin
        ID := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//ram:IssuerAssignedID');
        DocumentDescription := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//ram:Name');
        if TXRechnungXMLHelper.FindNode(nodes.item[i],'.//ram:URIID') then
          ExternalReference := TXRechnungXMLHelper.SelectNodeText(nodes.item[i],'.//ram:URIID')
        else
        if TXRechnungXMLHelper.SelectNode(nodes.item[i],'.//ram:AttachmentBinaryObject',node) then
        begin
          AttachmentType := TXRechnungHelper.InvoiceAttachmentTypeFromStr(TXRechnungXMLHelper.SelectAttributeText(node,'mimeCode'));
          Filename := TXRechnungXMLHelper.SelectAttributeText(node,'filename');
          SetDataFromBase64(node.Text);
        end;
      end;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:SpecifiedProcuringProject',node2) then
      begin
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:ID',node) then
          _Invoice.ProjectReference := node.text;
      end;
    end;
    if TXRechnungXMLHelper.SelectNode(nodeSupplyChainTradeTransaction,'.//ram:ApplicableHeaderTradeDelivery',nodeApplicableHeaderTradeAgreement) then
    begin
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:ShipToTradeParty',node2) then
      begin
        _Invoice.DeliveryInformation.Name := TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:Name');
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:PostalTradeAddress',node3) then
        begin
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:PostcodeCode',node) then
            _Invoice.DeliveryInformation.Address.PostalZone := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineOne',node) then
            _Invoice.DeliveryInformation.Address.StreetName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineTwo',node) then
            _Invoice.DeliveryInformation.Address.AdditionalStreetName := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:LineThree',node) then
            _Invoice.DeliveryInformation.Address.AddressLine := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CityName',node) then
            _Invoice.DeliveryInformation.Address.City := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CountryID',node) then
            _Invoice.DeliveryInformation.Address.CountryCode := node.text;
          if TXRechnungXMLHelper.SelectNode(node3,'.//ram:CountrySubDivisionName',node) then
            _Invoice.DeliveryInformation.Address.CountrySubentity := node.text;
        end;
      end;

      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:ActualDeliverySupplyChainEvent',node2) then
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:OccurrenceDateTime',node3) then
      if TXRechnungXMLHelper.SelectNode(node3,'.//udt:DateTimeString',node) then
        _Invoice.DeliveryInformation.ActualDeliveryDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(node.Text);

      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:DeliveryNoteReferencedDocument',node2) then
      if TXRechnungXMLHelper.SelectNode(node2,'.//ram:IssuerAssignedID',node3) then
        _Invoice.DeliveryReceiptNumber := Node3.text;
    end;
    if TXRechnungXMLHelper.SelectNode(nodeSupplyChainTradeTransaction,'.//ram:ApplicableHeaderTradeSettlement',nodeApplicableHeaderTradeAgreement) then
    begin
      _Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier := TXRechnungXMLHelper.SelectNodeText(nodeApplicableHeaderTradeAgreement,'.//ram:CreditorReferenceID');
      _Invoice.PaymentID := TXRechnungXMLHelper.SelectNodeText(nodeApplicableHeaderTradeAgreement,'.//ram:PaymentReference');
      _Invoice.InvoiceCurrencyCode := TXRechnungXMLHelper.SelectNodeText(nodeApplicableHeaderTradeAgreement,'.//ram:InvoiceCurrencyCode');
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:SpecifiedTradeSettlementPaymentMeans',node2) then
      begin
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:TypeCode',node) then
          _Invoice.PaymentMeansCode := TXRechnungHelper.InvoicePaymentMeansCodeFromStr(node.text);
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:PayeePartyCreditorFinancialAccount',node3) then
        begin
          _Invoice.PaymentFinancialAccount := TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:IBANID');
          _Invoice.PaymentFinancialAccountName := TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:AccountName');
        end;
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:PayeeSpecifiedCreditorFinancialInstitution',node3) then
          _Invoice.PaymentFinancialInstitutionBranch := TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:BICID');
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:PayerPartyDebtorFinancialAccount',node3) then
          _Invoice.PaymentFinancialAccount := TXRechnungXMLHelper.SelectNodeText(node3,'.//ram:IBANID');
      end;
      if TXRechnungXMLHelper.SelectNodes(nodeApplicableHeaderTradeAgreement,'.//ram:ApplicableTradeTax',nodes) then
      for i := 0 to nodes.length-1 do
      begin
        SetLength(_Invoice.TaxAmountSubtotals,Length(_Invoice.TaxAmountSubtotals)+1);
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:CalculatedAmount'));
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxExemptionReason := TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ExemptionReason');
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxableAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:BasisAmount'));
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxCategory := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:CategoryCode'));
        _Invoice.TaxAmountSubtotals[Length(_Invoice.TaxAmountSubtotals)-1].TaxPercent := TXRechnungHelper.PercentageFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:RateApplicablePercent'));
      end;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:BillingSpecifiedPeriod',node2) then
      begin
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:StartDateTime',node) then
          _Invoice.InvoicePeriodStartDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(TXRechnungXMLHelper.SelectNodeText(node,'.//udt:DateTimeString'));
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:EndDateTime',node) then
          _Invoice.InvoicePeriodEndDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(TXRechnungXMLHelper.SelectNodeText(node,'.//udt:DateTimeString'));
      end;
      if TXRechnungXMLHelper.SelectNodes(nodeApplicableHeaderTradeAgreement,'.//ram:SpecifiedTradeAllowanceCharge',nodes) then
      for i := 0 to nodes.length-1 do
      with _Invoice.AllowanceCharges.AddAllowanceCharge do
      begin
        if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ChargeIndicator',node2) then
        if TXRechnungXMLHelper.SelectNode(node2,'.//udt:Indicator',node) then
          ChargeIndicator := StrToBoolDef(node.text,false);
        MultiplierFactorNumeric := TXRechnungHelper.FloatFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:CalculationPercent'));
        BaseAmount  := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:BasisAmount'));
        Amount  := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ActualAmount'));
        if ChargeIndicator then
          ReasonCodeCharge := TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ReasonCode'))
        else
          ReasonCodeAllowance := TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeFromStr(TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:ReasonCode'));
        Reason := TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:Reason');
        if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:CategoryTradeTax',node2) then
        begin
          TaxCategory := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:CategoryCode'));
          TaxPercent := TXRechnungHelper.PercentageFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:RateApplicablePercent'));
        end;
      end;

      if TXRechnungXMLHelper.SelectNodes(nodeApplicableHeaderTradeAgreement,'.//ram:SpecifiedTradePaymentTerms',nodes) then
      begin
        if (nodes.length > 0) then
        if TXRechnungXMLHelper.FindNode(nodes[0],'.//ram:DirectDebitMandateID') then
          _Invoice.PaymentMandateID := TXRechnungXMLHelper.SelectNodeText(nodes[0],'.//ram:DirectDebitMandateID');
        _Invoice.PaymentTermsType := iptt_None;
        //XRechnung-Variante?
        if (nodes.length = 1) then
        if (TXRechnungXMLHelper.FindNode(nodes[0],'.//ram:DueDateDateTime') or
            (Pos('#SKONTO#',TXRechnungXMLHelper.SelectNodeText(nodes[0],'.//ram:Description')) > 0) ) then
        begin
          TXRechnungInvoiceAdapter301.InternalReadPaymentTerms(
            _Invoice,TXRechnungXMLHelper.SelectNodeText(nodes[0],'.//ram:Description'));
          if TXRechnungXMLHelper.SelectNode(nodes[0],'.//ram:DueDateDateTime',node3) then
          if TXRechnungXMLHelper.SelectNode(node3,'.//udt:DateTimeString',node) then
            _Invoice.InvoiceDueDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(node.text);
        end;
        //ZUGFeRD-Variante
        if _Invoice.PaymentTermsType = iptt_None then
        for i := 0 to nodes.length-1 do
        begin
          if _Invoice.PaymentTermsType = iptt_None then
          if TXRechnungXMLHelper.FindNode(nodes[i],'.//ram:DueDateDateTime') then
            _Invoice.PaymentTermsType := iptt_Net;

          if _Invoice.PaymentTermsType = iptt_None then
          case nodes.length of
            1 : _Invoice.PaymentTermsType := iptt_Net;
            2 : _Invoice.PaymentTermsType := iptt_CashDiscount1;
            else _Invoice.PaymentTermsType := iptt_CashDiscount2;
          end;
          if (_Invoice.PaymentTermsType = iptt_Net) or
             ((_Invoice.PaymentTermsType in [iptt_CashDiscount1,iptt_CashDiscount2]) and
              (nodes.length-1 = i)) then
          begin
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:DueDateDateTime',node3) then
            if TXRechnungXMLHelper.SelectNode(node3,'.//udt:DateTimeString',node) then
              _Invoice.InvoiceDueDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(node.text);
            _Invoice.PaymentTermNetNote := TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:Description');
          end;
          if (_Invoice.PaymentTermsType = iptt_CashDiscount2) and (i = 0) then
          begin
            _Invoice.PaymentTermCashDiscount2Days := 0;
            _Invoice.PaymentTermCashDiscount2Percent := 0;
            _Invoice.PaymentTermCashDiscount2Base := 0;
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ApplicableTradePaymentDiscountTerms/ram:BasisPeriodMeasure',node3) then
              _Invoice.PaymentTermCashDiscount2Days := StrToIntDef(node3.text,0);
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ApplicableTradePaymentDiscountTerms/ram:CalculationPercent',node3) then
              _Invoice.PaymentTermCashDiscount2Percent := TXRechnungHelper.FloatFromStr(node3.text);
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ApplicableTradePaymentDiscountTerms/ram:BasisAmount',node3) then
              _Invoice.PaymentTermCashDiscount2Base := TXRechnungHelper.FloatFromStr(node3.text);
          end;
          if ((_Invoice.PaymentTermsType = iptt_CashDiscount1) and (i = 0)) or
             ((_Invoice.PaymentTermsType = iptt_CashDiscount2) and (i = 1)) then
          begin
            _Invoice.PaymentTermCashDiscount1Days := 0;
            _Invoice.PaymentTermCashDiscount1Percent := 0;
            _Invoice.PaymentTermCashDiscount1Base := 0;
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ApplicableTradePaymentDiscountTerms/ram:BasisPeriodMeasure',node3) then
              _Invoice.PaymentTermCashDiscount1Days := StrToIntDef(node3.text,0);
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ApplicableTradePaymentDiscountTerms/ram:CalculationPercent',node3) then
              _Invoice.PaymentTermCashDiscount1Percent := TXRechnungHelper.FloatFromStr(node3.text);
            if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:ApplicableTradePaymentDiscountTerms/ram:BasisAmount',node3) then
              _Invoice.PaymentTermCashDiscount1Base := TXRechnungHelper.FloatFromStr(node3.text);
          end;
          //Theoretisch mehr Datenfelder
          //<ram:SpecifiedTradePaymentTerms>
          //  <ram:Description>Bis zum 09.03.2024 erhalten Sie 4,000  % Skonto</ram:Description>
          //  <ram:DirectDebitMandateID>33279700</ram:DirectDebitMandateID>
          //  <ram:ApplicableTradePaymentDiscountTerms>
          //    <ram:BasisDateTime><udt:DateTimeString format="102">20240228</udt:DateTimeString></ram:BasisDateTime>
          //    <ram:BasisPeriodMeasure unitCode="DAY">10</ram:BasisPeriodMeasure>
          //    <ram:BasisAmount>119.64</ram:BasisAmount>
          //    <ram:CalculationPercent>4.000</ram:CalculationPercent>
          //    <ram:ActualDiscountAmount>4.79</ram:ActualDiscountAmount>
          //  </ram:ApplicableTradePaymentDiscountTerms>
          //</ram:SpecifiedTradePaymentTerms>
          //<ram:SpecifiedTradePaymentTerms>
          //  <ram:Description>Bis zum 19.03.2024 ohne Abzug</ram:Description>
          //  <ram:DueDateDateTime><udt:DateTimeString format="102">20240319</udt:DateTimeString></ram:DueDateDateTime>
          //  <ram:DirectDebitMandateID>33279700</ram:DirectDebitMandateID>
          //</ram:SpecifiedTradePaymentTerms>
        end;
      end;
      if TXRechnungXMLHelper.SelectNode(nodeApplicableHeaderTradeAgreement,'.//ram:SpecifiedTradeSettlementHeaderMonetarySummation',node2) then
      begin
        _Invoice.LineAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:LineTotalAmount'));
        _Invoice.ChargeTotalAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:ChargeTotalAmount'));
        _Invoice.AllowanceTotalAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:AllowanceTotalAmount'));
        _Invoice.TaxExclusiveAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:TaxBasisTotalAmount'));
        if TXRechnungXMLHelper.SelectNode(node2,'.//ram:TaxTotalAmount',node) then
        begin
          _Invoice.TaxCurrencyCode := TXRechnungXMLHelper.SelectAttributeText(node,'currencyID');
          _Invoice.TaxAmountTotal := TXRechnungHelper.AmountFromStr(node.text);
        end;
        _Invoice.TaxInclusiveAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:GrandTotalAmount'));
        _Invoice.PrepaidAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:TotalPrepaidAmount'));
        _Invoice.PayableAmount := TXRechnungHelper.AmountFromStr(TXRechnungXMLHelper.SelectNodeText(node2,'.//ram:DuePayableAmount'));
      end;
      if TXRechnungXMLHelper.SelectNodes(nodeApplicableHeaderTradeAgreement,'.//ram:InvoiceReferencedDocument',nodes) then
      for i := 0 to nodes.length-1 do
      with _Invoice.PrecedingInvoiceReferences.AddPrecedingInvoiceReference do
      begin
        ID := TXRechnungXMLHelper.SelectNodeText(nodes[i],'.//ram:IssuerAssignedID');
        if TXRechnungXMLHelper.SelectNode(nodes[i],'.//ram:FormattedIssueDateTime',node2) then
        if TXRechnungXMLHelper.SelectNode(node2,'.//qdt:DateTimeString',node) then
          IssueDate := TXRechnungHelper.DateFromStrUNCEFACTFormat(node.text);
      end;

    end;
    Result := true;
  except
    on E:Exception do _Error := E.ClassName+' '+E.Message;
  end;
end;

class procedure TXRechnungInvoiceAdapter301.SaveDocumentUBL(_Invoice: TInvoice;
  _Xml: IXMLDocument);
var
  xRoot : IXMLNode;
  allowanceCharge : TInvoiceAllowanceCharge;
  taxSubtotal : TInvoiceTaxAmount;
  i : Integer;
  precedingInvoiceReference : TInvoicePrecedingInvoiceReference;

  function InternalExtensionEnabled : Boolean;
  //var a : Integer;
  begin
    Result := false;
    if _Invoice.InvoiceLines.Count > 0 then
    begin
      Result := true;
      exit;
    end;
    //for a := 0 to _Invoice.Attachments.Count-1 do
    //if _Invoice.Attachments[a].AttachmentType = TInvoiceAttachmentType.iat_application_xml then
    //begin
    //  Result := true;
    //  exit;
    //end;
  end;

  procedure InternalAddInvoiceLine(_Invoiceline : TInvoiceLine; _Node : IXMLNode);
  var
    subinvoiceline : TInvoiceLine;
    allowanceCharge : TInvoiceAllowanceCharge;
  begin
    _Node.AddChild('cbc:ID').Text := _Invoiceline.ID;
    if _Invoiceline.Note <> '' then
      _Node.AddChild('cbc:Note').Text := _Invoiceline.Note;
    with _Node.AddChild('cbc:InvoicedQuantity') do
    begin
      Attributes['unitCode'] := TXRechnungHelper.InvoiceUnitCodeToStr(_Invoiceline.UnitCode);
      Text := TXRechnungHelper.QuantityToStr(_Invoiceline.Quantity);
    end;
    with _Node.AddChild('cbc:LineExtensionAmount') do
    begin
      Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
      Text := TXRechnungHelper.AmountToStr(_Invoiceline.LineAmount);
    end;
    //  <cac:DocumentReference>
    //     <cbc:ID/>
    //     <cbc:DocumentType>916</cbc:DocumentType>
    //  </cac:DocumentReference>
    for allowanceCharge in _Invoiceline.AllowanceCharges do
    with _Node.AddChild('cac:AllowanceCharge') do
    begin
      AddChild('cbc:ChargeIndicator').Text := LowerCase(BoolToStr(allowanceCharge.ChargeIndicator,true));
      AddChild('cbc:AllowanceChargeReasonCode').Text :=
               IfThen(allowanceCharge.ChargeIndicator,
               TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeToStr(allowanceCharge.ReasonCodeCharge),
               TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeToStr(allowanceCharge.ReasonCodeAllowance));
      if not allowanceCharge.Reason.IsEmpty then
        AddChild('cbc:AllowanceChargeReason').Text := allowanceCharge.Reason;
      if allowanceCharge.MultiplierFactorNumeric <> 0 then
        AddChild('cbc:MultiplierFactorNumeric').Text := TXRechnungHelper.FloatToStr(allowanceCharge.MultiplierFactorNumeric);
      with AddChild('cbc:Amount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(allowanceCharge.Amount);
      end;
      with AddChild('cbc:BaseAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(allowanceCharge.BaseAmount);
      end;
    end;
    with _Node.AddChild('cac:Item') do
    begin
      if not _Invoiceline.Description.IsEmpty then
        AddChild('cbc:Description').Text := _Invoiceline.Description;
      AddChild('cbc:Name').Text := _Invoiceline.Name;
      //   <cac:BuyersItemIdentification>
      //      <cbc:ID/>
      //   </cac:BuyersItemIdentification>
      if not _Invoiceline.SellersItemIdentification.IsEmpty then
        AddChild('cac:SellersItemIdentification').AddChild('cbc:ID').Text := _Invoiceline.SellersItemIdentification;
      if _Invoiceline.GlobalID_EAN_GTIN <> '' then
      with AddChild('cac:StandardItemIdentification').AddChild('cbc:ID') do
      begin
        Attributes['schemeID'] := '0160';
        Text := _Invoiceline.GlobalID_EAN_GTIN;
      end;
      with AddChild('cac:ClassifiedTaxCategory') do
      begin
        AddChild('cbc:ID').Text := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeToStr(_Invoiceline.TaxCategory);
        AddChild('cbc:Percent').Text := TXRechnungHelper.PercentageToStr(_Invoiceline.TaxPercent);
        AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'VAT';
      end;
    end;
    with _Node.AddChild('cac:Price') do
    begin
      with AddChild('cbc:PriceAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.UnitPriceAmountToStr(_Invoiceline.NetPriceAmount);
      end;
      if (_Invoiceline.BaseQuantity <> 0) and (_Invoiceline.BaseQuantityUnitCode <> iuc_None) then
      with AddChild('cbc:BaseQuantity') do
      begin
        Attributes['unitCode'] := TXRechnungHelper.InvoiceUnitCodeToStr(_Invoiceline.BaseQuantityUnitCode);
        Text := TXRechnungHelper.FloatToStr(_Invoiceline.BaseQuantity);
      end;
      if (_Invoiceline.GrossPriceAmount <> 0) then
      with AddChild('cac:AllowanceCharge') do
      begin
        AddChild('cbc:ChargeIndicator').Text := 'false'; //false ist Pflicht, keine Zulage
        with AddChild('cbc:Amount') do
        begin
          Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
          Text := TXRechnungHelper.UnitPriceAmountToStr(_Invoiceline.DiscountOnTheGrossPrice);
        end;
        with AddChild('cbc:BaseAmount') do
        begin
          Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
          Text := TXRechnungHelper.UnitPriceAmountToStr(_Invoiceline.GrossPriceAmount);
        end;
      end;
    end;
    for subinvoiceline in _Invoiceline.SubInvoiceLines do
      InternalAddInvoiceLine(subinvoiceline,_Node.AddChild('cac:SubInvoiceLine'));
  end;

begin
  {$IFDEF USE_OXMLDomVendor}TXMLDocument(_Xml).DOMVendor := Xml.xmldom.GetDOMVendor(sOXmlDOMVendor);{$ENDIF}
  //Result := xmldoc.GetDocBinding('rsm:CrossIndustryInvoice', TXMLCrossIndustryDocumentType) as IXMLCrossIndustryDocumentType;
  TXMLDocument(_Xml).Options := TXMLDocument(_Xml).Options + [doNodeAutoIndent];
  _Xml.Active := True;
  _Xml.Version := '1.0';
  _Xml.StandAlone := 'yes';
  _Xml.Encoding := 'UTF-8';

  _Xml.Options := [doNodeAutoCreate, doNodeAutoIndent, doAttrNull];

  xRoot := _Xml.AddChild('ubl:Invoice');

  xRoot.DeclareNamespace('ubl','urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
  xRoot.DeclareNamespace('cac','urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
  xRoot.DeclareNamespace('cbc','urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');

  xRoot.AddChild('cbc:CustomizationID').Text := 'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0'+
           IfThen(InternalExtensionEnabled,'#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0','');
  xRoot.AddChild('cbc:ProfileID').Text := 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';

  xRoot.AddChild('cbc:ID').Text := _Invoice.InvoiceNumber;
  xRoot.AddChild('cbc:IssueDate').Text := TXRechnungHelper.DateToStrUBLFormat(_Invoice.InvoiceIssueDate);
  if _Invoice.InvoiceDueDate > 100 then xRoot.AddChild('cbc:DueDate').Text := TXRechnungHelper.DateToStrUBLFormat(_Invoice.InvoiceDueDate);
  xRoot.AddChild('cbc:InvoiceTypeCode').Text := TXRechnungHelper.InvoiceTypeCodeToStr(_Invoice.InvoiceTypeCode);
  for i := 0 to _Invoice.Notes.Count-1 do
    xRoot.AddChild('cbc:Note').Text := _Invoice.Notes[i].Content;
  xRoot.AddChild('cbc:DocumentCurrencyCode').Text := _Invoice.InvoiceCurrencyCode;
  //xRoot.AddChild('cbc:TaxCurrencyCode').Text := _Invoice.TaxCurrencyCode; //Nicht in XRechnung 3
  xRoot.AddChild('cbc:BuyerReference').Text := _Invoice.BuyerReference;
  if (_Invoice.InvoicePeriodStartDate > 100) and (_Invoice.InvoicePeriodEndDate > 100) then
  with xRoot.AddChild('cac:InvoicePeriod') do
  begin
    AddChild('cbc:StartDate').Text := TXRechnungHelper.DateToStrUBLFormat(_Invoice.InvoicePeriodStartDate);
    AddChild('cbc:EndDate').Text := TXRechnungHelper.DateToStrUBLFormat(_Invoice.InvoicePeriodEndDate);
  end;
  if _Invoice.PurchaseOrderReference <> '' then
    xRoot.AddChild('cac:OrderReference').AddChild('cbc:ID').Text := _Invoice.PurchaseOrderReference
  else
  if _Invoice.SellerOrderReference <> '' then
    xRoot.AddChild('cac:OrderReference').AddChild('cbc:ID').Text := _Invoice.SellerOrderReference;
  for precedingInvoiceReference in _Invoice.PrecedingInvoiceReferences do
  with xRoot.AddChild('cac:BillingReference').AddChild('cac:InvoiceDocumentReference') do
  begin
    AddChild('cbc:ID').Text := precedingInvoiceReference.ID;
    AddChild('cbc:IssueDate').Text := TXRechnungHelper.DateToStrUBLFormat(precedingInvoiceReference.IssueDate);
  end;
  if _Invoice.DeliveryReceiptNumber <> '' then
    xRoot.AddChild('cac:DespatchDocumentReference').AddChild('cbc:ID').Text := _Invoice.DeliveryReceiptNumber;
  if _Invoice.ContractDocumentReference <> '' then
    xRoot.AddChild('cac:ContractDocumentReference').AddChild('cbc:ID').Text := _Invoice.ContractDocumentReference;

  for i := 0 to _Invoice.Attachments.Count -1 do
  begin
    with xRoot.AddChild('cac:AdditionalDocumentReference') do
    begin
      AddChild('cbc:ID').Text := _Invoice.Attachments[i].ID;
      if _Invoice.Attachments[i].DocumentDescription <> '' then
        AddChild('cbc:DocumentDescription').Text := _Invoice.Attachments[i].DocumentDescription;
      with AddChild('cac:Attachment') do
      begin
        if _Invoice.Attachments[i].ExternalReference <> '' then
        begin
          AddChild('cac:ExternalReference').AddChild('cbc:URI').Text := _Invoice.Attachments[i].ExternalReference;
        end else
        with AddChild('cbc:EmbeddedDocumentBinaryObject') do
        begin
          Attributes['mimeCode'] := TXRechnungHelper.InvoiceAttachmentTypeToStr(_Invoice.Attachments[i].AttachmentType);
          Attributes['filename'] := _Invoice.Attachments[i].Filename;
          Text := _Invoice.Attachments[i].GetDataAsBase64;
        end;
      end;
    end;
  end;

  if _Invoice.ProjectReference <> '' then
    xRoot.AddChild('cac:ProjectReference').AddChild('cbc:ID').Text := _Invoice.ProjectReference;

  with xRoot.AddChild('cac:AccountingSupplierParty').AddChild('cac:Party') do
  begin
    if _Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyer <> '' then
    with AddChild('cbc:EndpointID') do
    begin
      Attributes['schemeID'] := 'EM';
      Text := _Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyer;
    end;
    if _Invoice.AccountingSupplierParty.IdentifierSellerBuyer <> '' then
    with AddChild('cac:PartyIdentification').AddChild('cbc:ID') do
    begin
      Attributes['schemeID'] := '0088';
      Text := _Invoice.AccountingSupplierParty.IdentifierSellerBuyer;
    end;
    if _Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier <> '' then
    with AddChild('cac:PartyIdentification').AddChild('cbc:ID') do
    begin
      Attributes['schemeID'] := 'SEPA';
      Text := _Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier;
    end;
    with AddChild('cac:PartyName') do
    begin
      AddChild('cbc:Name').Text := _Invoice.AccountingSupplierParty.Name;
    end;
    with AddChild('cac:PostalAddress') do
    begin
      AddChild('cbc:StreetName').Text := _Invoice.AccountingSupplierParty.Address.StreetName;
      if _Invoice.AccountingSupplierParty.Address.AdditionalStreetName <> '' then
        AddChild('cbc:AdditionalStreetName').Text := _Invoice.AccountingSupplierParty.Address.AdditionalStreetName;
      AddChild('cbc:CityName').Text := _Invoice.AccountingSupplierParty.Address.City;
      AddChild('cbc:PostalZone').Text := _Invoice.AccountingSupplierParty.Address.PostalZone;
      if _Invoice.AccountingSupplierParty.Address.CountrySubentity <> '' then
        AddChild('cbc:CountrySubentity').Text := _Invoice.AccountingSupplierParty.Address.CountrySubentity;
      if _Invoice.AccountingSupplierParty.Address.AddressLine <> '' then
        AddChild('cac:AddressLine').AddChild('cbc:Line').Text := _Invoice.AccountingSupplierParty.Address.AddressLine;
      AddChild('cac:Country').AddChild('cbc:IdentificationCode').Text := _Invoice.AccountingSupplierParty.Address.CountryCode;
    end;
    if _Invoice.AccountingSupplierParty.VATCompanyID <> '' then
    with AddChild('cac:PartyTaxScheme') do
    begin
      AddChild('cbc:CompanyID').Text := _Invoice.AccountingSupplierParty.VATCompanyID;
      AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'VAT';
    end;
    if _Invoice.AccountingSupplierParty.VATCompanyNumber <> '' then
    with AddChild('cac:PartyTaxScheme') do
    begin
      AddChild('cbc:CompanyID').Text := _Invoice.AccountingSupplierParty.VATCompanyNumber;
      AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'FC';
    end;
    with AddChild('cac:PartyLegalEntity') do
    begin
      AddChild('cbc:RegistrationName').Text := _Invoice.AccountingSupplierParty.RegistrationName;
      if _Invoice.AccountingSupplierParty.CompanyID <> '' then
        AddChild('cbc:CompanyID').Text := _Invoice.AccountingSupplierParty.CompanyID;
      if not _Invoice.AccountingSupplierParty.AdditionalLegalInformationSeller.IsEmpty then
        AddChild('cbc:CompanyLegalForm').Text := _Invoice.AccountingSupplierParty.AdditionalLegalInformationSeller;
    end;
    with AddChild('cac:Contact') do
    begin
      AddChild('cbc:Name').Text := _Invoice.AccountingSupplierParty.ContactName;
      AddChild('cbc:Telephone').Text := _Invoice.AccountingSupplierParty.ContactTelephone;
      AddChild('cbc:ElectronicMail').Text := _Invoice.AccountingSupplierParty.ContactElectronicMail;
    end;
  end;

  with xRoot.AddChild('cac:AccountingCustomerParty').AddChild('cac:Party') do
  begin
    if _Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyer <> '' then
    with AddChild('cbc:EndpointID') do
    begin
      Attributes['schemeID'] := 'EM';
      Text := _Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyer;
    end;
    if _Invoice.AccountingCustomerParty.IdentifierSellerBuyer <> '' then
    with AddChild('cac:PartyIdentification').AddChild('cbc:ID') do
    begin
      Attributes['schemeID'] := '0088';
      Text := _Invoice.AccountingCustomerParty.IdentifierSellerBuyer;
    end;
    with AddChild('cac:PartyName') do
    begin
      AddChild('cbc:Name').Text := _Invoice.AccountingCustomerParty.Name;
    end;
    with AddChild('cac:PostalAddress') do
    begin
      AddChild('cbc:StreetName').Text := _Invoice.AccountingCustomerParty.Address.StreetName;
      if _Invoice.AccountingCustomerParty.Address.AdditionalStreetName <> '' then
        AddChild('cbc:AdditionalStreetName').Text := _Invoice.AccountingCustomerParty.Address.AdditionalStreetName;
      AddChild('cbc:CityName').Text := _Invoice.AccountingCustomerParty.Address.City;
      AddChild('cbc:PostalZone').Text := _Invoice.AccountingCustomerParty.Address.PostalZone;
      if _Invoice.AccountingCustomerParty.Address.CountrySubentity <> '' then
        AddChild('cbc:CountrySubentity').Text := _Invoice.AccountingCustomerParty.Address.CountrySubentity;
      if _Invoice.AccountingCustomerParty.Address.AddressLine <> '' then
        AddChild('cac:AddressLine').AddChild('cbc:Line').Text := _Invoice.AccountingCustomerParty.Address.AddressLine;
      AddChild('cac:Country').AddChild('cbc:IdentificationCode').Text := _Invoice.AccountingCustomerParty.Address.CountryCode;
    end;
    if _Invoice.AccountingCustomerParty.VATCompanyID <> '' then
    with AddChild('cac:PartyTaxScheme') do
    begin
      AddChild('cbc:CompanyID').Text := _Invoice.AccountingCustomerParty.VATCompanyID;
      AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'VAT';
    end;
    if _Invoice.AccountingCustomerParty.VATCompanyNumber <> '' then
    with AddChild('cac:PartyTaxScheme') do
    begin
      AddChild('cbc:CompanyID').Text := _Invoice.AccountingCustomerParty.VATCompanyNumber;
      AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'FC';
    end;
    with AddChild('cac:PartyLegalEntity') do
    begin
      AddChild('cbc:RegistrationName').Text := _Invoice.AccountingCustomerParty.RegistrationName;
      if _Invoice.AccountingCustomerParty.CompanyID <> '' then
        AddChild('cbc:CompanyID').Text := _Invoice.AccountingCustomerParty.CompanyID;
    end;
    if (_Invoice.AccountingCustomerParty.ContactName <> '') or
       (_Invoice.AccountingCustomerParty.ContactTelephone <> '') or
       (_Invoice.AccountingCustomerParty.ContactElectronicMail <> '') then
    with AddChild('cac:Contact') do
    begin
      if (_Invoice.AccountingCustomerParty.ContactName <> '') then
        AddChild('cbc:Name').Text := _Invoice.AccountingCustomerParty.ContactName;
      if (_Invoice.AccountingCustomerParty.ContactTelephone <> '') then
        AddChild('cbc:Telephone').Text := _Invoice.AccountingCustomerParty.ContactTelephone;
      if (_Invoice.AccountingCustomerParty.ContactElectronicMail <> '') then
        AddChild('cbc:ElectronicMail').Text := _Invoice.AccountingCustomerParty.ContactElectronicMail;
    end;
  end;

  if (_Invoice.DeliveryInformation.ActualDeliveryDate > 0) or
     (_Invoice.DeliveryInformation.Address.CountryCode <> '') or
     (_Invoice.DeliveryInformation.Name <> '') then
  with xRoot.AddChild('cac:Delivery') do
  begin
    if (_Invoice.DeliveryInformation.ActualDeliveryDate > 0) then
      AddChild('cbc:ActualDeliveryDate').Text := TXRechnungHelper.DateToStrUBLFormat(_Invoice.DeliveryInformation.ActualDeliveryDate);
    with AddChild('cac:DeliveryLocation') do
    begin
      //if (_Invoice.DeliveryInformation.LocationIdentifier <> '') then
      //  AddChild('cbc:ID').Text := _Invoice.DeliveryInformation.LocationIdentifier; //TODO schemeID https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-Delivery/cac-DeliveryLocation/cbc-ID/
      with AddChild('cac:Address') do
      begin
        AddChild('cbc:StreetName').Text := _Invoice.DeliveryInformation.Address.StreetName;
        if _Invoice.DeliveryInformation.Address.AdditionalStreetName <> '' then
          AddChild('cbc:AdditionalStreetName').Text := _Invoice.DeliveryInformation.Address.AdditionalStreetName;
        AddChild('cbc:CityName').Text := _Invoice.DeliveryInformation.Address.City;
        AddChild('cbc:PostalZone').Text := _Invoice.DeliveryInformation.Address.PostalZone;
        if _Invoice.DeliveryInformation.Address.CountrySubentity <> '' then
          AddChild('cbc:CountrySubentity').Text := _Invoice.DeliveryInformation.Address.CountrySubentity;
        if _Invoice.DeliveryInformation.Address.AddressLine <> '' then
          AddChild('cac:AddressLine').AddChild('cbc:Line').Text := _Invoice.DeliveryInformation.Address.AddressLine;
        AddChild('cac:Country').AddChild('cbc:IdentificationCode').Text := _Invoice.DeliveryInformation.Address.CountryCode;
      end;
    end;
    if (_Invoice.DeliveryInformation.Name <> '') then
      AddChild('cac:DeliveryParty').AddChild('cac:PartyName').AddChild('cbc:Name').Text := _Invoice.DeliveryInformation.Name;
  end;

  with xRoot.AddChild('cac:PaymentMeans') do
  begin
    AddChild('cbc:PaymentMeansCode').Text := TXRechnungHelper.InvoicePaymentMeansCodeToStr(_Invoice.PaymentMeansCode);
    if _Invoice.PaymentID <> '' then
      AddChild('cbc:PaymentID').Text := _Invoice.PaymentID;
    if (_Invoice.PaymentFinancialAccount <> '') then
    begin
      if _Invoice.PaymentMeansCode = ipmc_SEPADirectDebit then
      begin
        with AddChild('cac:PaymentMandate') do
        begin
          AddChild('cbc:ID').Text := _Invoice.PaymentMandateID;
          with AddChild('cac:PayerFinancialAccount') do
            AddChild('cbc:ID').Text := _Invoice.PaymentFinancialAccount;
        end;
      end else
      begin
        with AddChild('cac:PayeeFinancialAccount') do
        begin
          AddChild('cbc:ID').Text := _Invoice.PaymentFinancialAccount;
          if _Invoice.PaymentFinancialAccountName <> '' then
            AddChild('cbc:Name').Text := _Invoice.PaymentFinancialAccountName;
          if _Invoice.PaymentFinancialInstitutionBranch <> '' then
            AddChild('cac:FinancialInstitutionBranch').AddChild('cbc:ID').Text := _Invoice.PaymentFinancialInstitutionBranch;
        end;
      end;
    end;
  end;

  case _Invoice.PaymentTermsType of
    iptt_Net:
      if _Invoice.PaymentTermNetNote <> '' then
      with xRoot.AddChild('cac:PaymentTerms') do
      begin
        AddChild('cbc:Note').Text := System.StrUtils.ReplaceText(_Invoice.PaymentTermNetNote,'#',' ');
      end;
    iptt_CashDiscount1:
      with xRoot.AddChild('cac:PaymentTerms') do
      begin
        AddChild('cbc:Note').Text := Format('#SKONTO#TAGE=%d#PROZENT=%s#',
          [_Invoice.PaymentTermCashDiscount1Days,
           TXRechnungHelper.FloatToStr(_Invoice.PaymentTermCashDiscount1Percent)])+
          IfThen(_Invoice.PaymentTermCashDiscount1Base <> 0,'BASISBETRAG='+
            TXRechnungHelper.AmountToStr(_Invoice.PaymentTermCashDiscount1Base)+'#','')+#13#10;
      end;
    iptt_CashDiscount2:
    begin
      with xRoot.AddChild('cac:PaymentTerms') do
      begin
        AddChild('cbc:Note').Text := Format('#SKONTO#TAGE=%d#PROZENT=%s#',
          [_Invoice.PaymentTermCashDiscount1Days,
           TXRechnungHelper.FloatToStr(_Invoice.PaymentTermCashDiscount1Percent)])+
          IfThen(_Invoice.PaymentTermCashDiscount1Base <> 0,'BASISBETRAG='+
            TXRechnungHelper.AmountToStr(_Invoice.PaymentTermCashDiscount1Base)+'#','')+
          #13#10+
          Format('#SKONTO#TAGE=%d#PROZENT=%s#',
          [_Invoice.PaymentTermCashDiscount2Days,
           TXRechnungHelper.FloatToStr(_Invoice.PaymentTermCashDiscount2Percent)])+
          IfThen(_Invoice.PaymentTermCashDiscount2Base <> 0,'BASISBETRAG='+
            TXRechnungHelper.AmountToStr(_Invoice.PaymentTermCashDiscount2Base)+'#','')+#13#10;
      end;
    end;
  end;

  for allowanceCharge in _Invoice.AllowanceCharges do
  with xRoot.AddChild('cac:AllowanceCharge') do
  begin
    AddChild('cbc:ChargeIndicator').Text := LowerCase(BoolToStr(allowanceCharge.ChargeIndicator,true));
    AddChild('cbc:AllowanceChargeReasonCode').Text :=
             IfThen(allowanceCharge.ChargeIndicator,
             TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeToStr(allowanceCharge.ReasonCodeCharge),
             TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeToStr(allowanceCharge.ReasonCodeAllowance));
    if not allowanceCharge.Reason.IsEmpty then
      AddChild('cbc:AllowanceChargeReason').Text := allowanceCharge.Reason;
    if allowanceCharge.MultiplierFactorNumeric <> 0 then
      AddChild('cbc:MultiplierFactorNumeric').Text := TXRechnungHelper.FloatToStr(allowanceCharge.MultiplierFactorNumeric);
    with AddChild('cbc:Amount') do
    begin
      Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
      Text := TXRechnungHelper.AmountToStr(allowanceCharge.Amount);
    end;
    if allowanceCharge.BaseAmount <> 0 then
    with AddChild('cbc:BaseAmount') do
    begin
      Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
      Text := TXRechnungHelper.AmountToStr(allowanceCharge.BaseAmount);
    end;
    with AddChild('cac:TaxCategory') do
    begin
      AddChild('cbc:ID').Text := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeToStr(allowanceCharge.TaxCategory);
      AddChild('cbc:Percent').Text := TXRechnungHelper.PercentageToStr(allowanceCharge.TaxPercent);
      AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'VAT';
    end;
  end;

  with xRoot.AddChild('cac:TaxTotal') do
  begin
    with AddChild('cbc:TaxAmount') do
    begin
      Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
      Text := TXRechnungHelper.AmountToStr(_Invoice.TaxAmountTotal);
    end;
    for taxSubtotal in _Invoice.TaxAmountSubtotals do
    with AddChild('cac:TaxSubtotal') do
    begin
      with AddChild('cbc:TaxableAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(taxSubtotal.TaxableAmount);
      end;
      with AddChild('cbc:TaxAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(taxSubtotal.TaxAmount);
      end;
      with AddChild('cac:TaxCategory') do
      begin
        AddChild('cbc:ID').Text := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeToStr(taxSubtotal.TaxCategory);
        AddChild('cbc:Percent').Text := TXRechnungHelper.PercentageToStr(taxSubtotal.TaxPercent);
        if taxSubtotal.TaxExemptionReason <> '' then
          AddChild('cbc:TaxExemptionReason').Text := taxSubtotal.TaxExemptionReason;
        AddChild('cac:TaxScheme').AddChild('cbc:ID').Text := 'VAT';
      end;
    end;
  end;

  with xRoot.AddChild('cac:LegalMonetaryTotal') do
  begin
      with AddChild('cbc:LineExtensionAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.LineAmount);
      end;
      with AddChild('cbc:TaxExclusiveAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.TaxExclusiveAmount);
      end;
      with AddChild('cbc:TaxInclusiveAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.TaxInclusiveAmount);
      end;
      with AddChild('cbc:AllowanceTotalAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.AllowanceTotalAmount);
      end;
      with AddChild('cbc:ChargeTotalAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.ChargeTotalAmount);
      end;
      with AddChild('cbc:PrepaidAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.PrepaidAmount);
      end;
      //      <cbc:PayableRoundingAmount currencyID="EUR">0</cbc:PayableRoundingAmount>
      with AddChild('cbc:PayableAmount') do
      begin
        Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
        Text := TXRechnungHelper.AmountToStr(_Invoice.PayableAmount);
      end;
  end;

  for i := 0 to _Invoice.InvoiceLines.Count-1 do
    InternalAddInvoiceLine(_Invoice.InvoiceLines[i],xRoot.AddChild('cac:InvoiceLine'));
end;

class procedure TXRechnungInvoiceAdapter301.SaveDocumentUNCEFACT(
  _Invoice: TInvoice; _Xml: IXMLDocument);
var
  xRoot : IXMLNode;
  allowanceCharge : TInvoiceAllowanceCharge;
  taxSubtotal : TInvoiceTaxAmount;
  i : Integer;
  precedingInvoiceReference : TInvoicePrecedingInvoiceReference;

  procedure InternalAddInvoiceLine(_Invoiceline : TInvoiceLine; _Node : IXMLNode);
  var
    allowanceCharge : TInvoiceAllowanceCharge;
  begin
    with _Node.AddChild('ram:AssociatedDocumentLineDocument') do
    begin
      AddChild('ram:LineID').Text := _Invoiceline.ID;
      if _Invoiceline.Note <> '' then
        AddChild('ram:IncludedNote').AddChild('ram:Content').Text := _Invoiceline.Note;
    end;
    with _Node.AddChild('ram:SpecifiedTradeProduct') do
    begin
      if _Invoiceline.GlobalID_EAN_GTIN <> '' then
      begin
        with AddChild('ram:GlobalID') do
        begin
          Attributes['schemeID'] := '0160';
          Text := _Invoiceline.GlobalID_EAN_GTIN;
        end;
      end;
      if not _Invoiceline.SellersItemIdentification.IsEmpty then
        AddChild('ram:SellerAssignedID').Text := _Invoiceline.SellersItemIdentification;
      AddChild('ram:Name').Text := _Invoiceline.Name;
      if not _Invoiceline.Description.IsEmpty then
        AddChild('ram:Description').Text := _Invoiceline.Description;
    end;
    with _Node.AddChild('ram:SpecifiedLineTradeAgreement') do
    begin
//        <ram:BuyerOrderReferencedDocument>
//            <ram:LineID>6171175.1</ram:LineID>
//        </ram:BuyerOrderReferencedDocument>
//        <cac:OrderLineReference>
//            <cbc:LineID>6171175.1</cbc:LineID>
//        </cac:OrderLineReference>
      if _Invoiceline.GrossPriceAmount <> 0 then
      with AddChild('ram:GrossPriceProductTradePrice') do
      begin
        AddChild('ram:ChargeAmount').Text := TXRechnungHelper.UnitPriceAmountToStr(_Invoiceline.GrossPriceAmount);
        if (_Invoiceline.BaseQuantity <> 0) and (_Invoiceline.BaseQuantityUnitCode <> iuc_None) then
        with AddChild('ram:BasisQuantity') do
        begin
          Attributes['unitCode'] := TXRechnungHelper.InvoiceUnitCodeToStr(_Invoiceline.BaseQuantityUnitCode);
          Text := TXRechnungHelper.FloatToStr(_Invoiceline.BaseQuantity);
        end;
        if _Invoiceline.DiscountOnTheGrossPrice <> 0 then
        with AddChild('ram:AppliedTradeAllowanceCharge') do
        begin
          AddChild('ram:ChargeIndicator').AddChild('udt:Indicator').Text := 'false';
          //<ram:CalculationPercent>45</ram:CalculationPercent> nicht m�glich bei UBL
          AddChild('ram:ActualAmount').Text := TXRechnungHelper.UnitPriceAmountToStr(_Invoiceline.DiscountOnTheGrossPrice);
          //<ram:Reason>Rabatt1</ram:Reason> nicht m�glich bei UBL
        end;
      end;
      with AddChild('ram:NetPriceProductTradePrice') do
      begin
        AddChild('ram:ChargeAmount').Text := TXRechnungHelper.UnitPriceAmountToStr(_Invoiceline.NetPriceAmount);
        if (_Invoiceline.BaseQuantity <> 0) and (_Invoiceline.BaseQuantityUnitCode <> iuc_None) then
        with AddChild('ram:BasisQuantity') do
        begin
          Attributes['unitCode'] := TXRechnungHelper.InvoiceUnitCodeToStr(_Invoiceline.BaseQuantityUnitCode);
          Text := TXRechnungHelper.FloatToStr(_Invoiceline.BaseQuantity);
        end;
      end;
    end;
    with _Node.AddChild('ram:SpecifiedLineTradeDelivery').AddChild('ram:BilledQuantity') do
    begin
      Attributes['unitCode'] := TXRechnungHelper.InvoiceUnitCodeToStr(_Invoiceline.UnitCode);
      Text := TXRechnungHelper.QuantityToStr(_Invoiceline.Quantity);
    end;
    with _Node.AddChild('ram:SpecifiedLineTradeSettlement') do
    begin
      with AddChild('ram:ApplicableTradeTax') do
      begin
        AddChild('ram:TypeCode').Text := 'VAT';
        AddChild('ram:CategoryCode').Text := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeToStr(_Invoiceline.TaxCategory);
        AddChild('ram:RateApplicablePercent').Text := TXRechnungHelper.PercentageToStr(_Invoiceline.TaxPercent);
      end;
      for allowanceCharge in _Invoiceline.AllowanceCharges do
      with AddChild('ram:SpecifiedTradeAllowanceCharge') do
      begin
        AddChild('ram:ChargeIndicator').AddChild('udt:Indicator').Text := LowerCase(BoolToStr(allowanceCharge.ChargeIndicator,true));
        if allowanceCharge.MultiplierFactorNumeric <> 0 then
          AddChild('ram:CalculationPercent').Text := TXRechnungHelper.FloatToStr(allowanceCharge.MultiplierFactorNumeric);
        AddChild('ram:BasisAmount').Text := TXRechnungHelper.AmountToStr(allowanceCharge.BaseAmount);
        AddChild('ram:ActualAmount').Text := TXRechnungHelper.AmountToStr(allowanceCharge.Amount);
        AddChild('ram:ReasonCode').Text :=
                 IfThen(allowanceCharge.ChargeIndicator,
                 TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeToStr(allowanceCharge.ReasonCodeCharge),
                 TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeToStr(allowanceCharge.ReasonCodeAllowance));
        if not allowanceCharge.Reason.IsEmpty then
          AddChild('ram:Reason').Text := allowanceCharge.Reason;
      end;
      with AddChild('ram:SpecifiedTradeSettlementLineMonetarySummation') do
      begin
        AddChild('ram:LineTotalAmount').Text := TXRechnungHelper.AmountToStr(_Invoiceline.LineAmount);
      end;
    end;
    if _Invoiceline.SubInvoiceLines.Count > 0 then
      raise Exception.Create('SubInvoiceLines in UNCEFACT not implemented');
  end;

begin
  {$IFDEF USE_OXMLDomVendor}TXMLDocument(_Xml).DOMVendor := Xml.xmldom.GetDOMVendor(sOXmlDOMVendor);{$ENDIF}
  //Result := xmldoc.GetDocBinding('rsm:CrossIndustryInvoice', TXMLCrossIndustryDocumentType) as IXMLCrossIndustryDocumentType;
  TXMLDocument(_Xml).Options := TXMLDocument(_Xml).Options + [doNodeAutoIndent];
  _Xml.Active := True;
  _Xml.Version := '1.0';
  _Xml.StandAlone := 'yes';
  _Xml.Encoding := 'UTF-8';

  _Xml.Options := [doNodeAutoCreate, doNodeAutoIndent, doAttrNull];

  xRoot := _Xml.AddChild('rsm:CrossIndustryInvoice');

  xRoot.DeclareNamespace('rsm','urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100');
  xRoot.DeclareNamespace('ram','urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100');
  xRoot.DeclareNamespace('udt','urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100');
  xRoot.DeclareNamespace('qdt','urn:un:unece:uncefact:data:standard:QualifiedDataType:100');

  with xRoot.AddChild('rsm:ExchangedDocumentContext') do
  begin
    AddChild('ram:BusinessProcessSpecifiedDocumentContextParameter')
      .AddChild('ram:ID').Text := 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';

    AddChild('ram:GuidelineSpecifiedDocumentContextParameter')
      .AddChild('ram:ID').Text := 'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0';
  end;

  with xRoot.AddChild('rsm:ExchangedDocument') do
  begin
    AddChild('ram:ID').Text := _Invoice.InvoiceNumber;
    AddChild('ram:TypeCode').Text := TXRechnungHelper.InvoiceTypeCodeToStr(_Invoice.InvoiceTypeCode);
    with AddChild('ram:IssueDateTime').AddChild('udt:DateTimeString') do
    begin
      Attributes['format'] := '102';
      Text := TXRechnungHelper.DateToStrUNCEFACTFormat(_Invoice.InvoiceIssueDate);
    end;
    for i := 0 to _Invoice.Notes.Count-1 do
    with AddChild('ram:IncludedNote') do
    begin
      AddChild('ram:Content').Text := _Invoice.Notes[i].Content;
      //TODO <ram:SubjectCode>ADU</ram:SubjectCode>, bei UBL auch
    end;
  end;

  with xRoot.AddChild('rsm:SupplyChainTradeTransaction') do
  begin
    for i := 0 to _Invoice.InvoiceLines.Count-1 do
      InternalAddInvoiceLine(_Invoice.InvoiceLines[i],AddChild('ram:IncludedSupplyChainTradeLineItem'));

    with AddChild('ram:ApplicableHeaderTradeAgreement') do
    begin
      AddChild('ram:BuyerReference').Text := _Invoice.BuyerReference;

      with AddChild('ram:SellerTradeParty') do
      begin
        if _Invoice.AccountingSupplierParty.IdentifierSellerBuyer <> '' then
          AddChild('ram:ID').Text := _Invoice.AccountingSupplierParty.IdentifierSellerBuyer;
        AddChild('ram:Name').Text := _Invoice.AccountingSupplierParty.RegistrationName;
        if _Invoice.AccountingSupplierParty.AdditionalLegalInformationSeller <> '' then
          AddChild('ram:Description').Text := _Invoice.AccountingSupplierParty.AdditionalLegalInformationSeller;
        with AddChild('ram:SpecifiedLegalOrganization') do
        begin
          if _Invoice.AccountingSupplierParty.CompanyID <> '' then
            AddChild('ram:ID').Text := _Invoice.AccountingSupplierParty.CompanyID;
          AddChild('ram:TradingBusinessName').Text := _Invoice.AccountingSupplierParty.Name;
        end;
        with AddChild('ram:DefinedTradeContact') do
        begin
          AddChild('ram:PersonName').Text := _Invoice.AccountingSupplierParty.ContactName;
          AddChild('ram:TelephoneUniversalCommunication').AddChild('ram:CompleteNumber').Text := _Invoice.AccountingSupplierParty.ContactTelephone;
          AddChild('ram:EmailURIUniversalCommunication').AddChild('ram:URIID').Text := _Invoice.AccountingSupplierParty.ContactElectronicMail;
        end;
        with AddChild('ram:PostalTradeAddress') do
        begin
          AddChild('ram:PostcodeCode').Text := _Invoice.AccountingSupplierParty.Address.PostalZone;
          AddChild('ram:LineOne').Text := _Invoice.AccountingSupplierParty.Address.StreetName;
          if _Invoice.AccountingSupplierParty.Address.AdditionalStreetName <> '' then
            AddChild('ram:LineTwo').Text := _Invoice.AccountingSupplierParty.Address.AdditionalStreetName;
          if _Invoice.AccountingSupplierParty.Address.AddressLine <> '' then
            AddChild('ram:LineThree').Text := _Invoice.AccountingSupplierParty.Address.AddressLine;
          AddChild('ram:CityName').Text := _Invoice.AccountingSupplierParty.Address.City;
          AddChild('ram:CountryID').Text := _Invoice.AccountingSupplierParty.Address.CountryCode;
          if _Invoice.AccountingSupplierParty.Address.CountrySubentity <> '' then
            AddChild('ram:CountrySubDivisionName').Text := _Invoice.AccountingSupplierParty.Address.CountrySubentity;
        end;
        if _Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyer <> '' then
        with AddChild('ram:URIUniversalCommunication').AddChild('ram:URIID') do
        begin
          Attributes['schemeID'] := 'EM';
          Text := _Invoice.AccountingSupplierParty.ElectronicAddressSellerBuyer;
        end;
        if _Invoice.AccountingSupplierParty.VATCompanyID <> '' then
        with AddChild('ram:SpecifiedTaxRegistration').AddChild('ram:ID') do
        begin
          Attributes['schemeID'] := 'VA';
          Text := _Invoice.AccountingSupplierParty.VATCompanyID;
        end;
        if _Invoice.AccountingSupplierParty.VATCompanyNumber <> '' then
        with AddChild('ram:SpecifiedTaxRegistration').AddChild('ram:ID') do
        begin
          Attributes['schemeID'] := 'FC';
          Text := _Invoice.AccountingSupplierParty.VATCompanyNumber;
        end;
      end;
      with AddChild('ram:BuyerTradeParty') do
      begin
        if _Invoice.AccountingCustomerParty.IdentifierSellerBuyer <> '' then
          AddChild('ram:ID').Text := _Invoice.AccountingCustomerParty.IdentifierSellerBuyer;
        AddChild('ram:Name').Text := _Invoice.AccountingCustomerParty.RegistrationName;

        with AddChild('ram:SpecifiedLegalOrganization') do
        begin
          if _Invoice.AccountingCustomerParty.CompanyID <> '' then
            AddChild('ram:ID').Text := _Invoice.AccountingCustomerParty.CompanyID;
          AddChild('ram:TradingBusinessName').Text := _Invoice.AccountingCustomerParty.Name;
        end;
        if (_Invoice.AccountingCustomerParty.ContactName <> '') or
           (_Invoice.AccountingCustomerParty.ContactTelephone <> '') or
           (_Invoice.AccountingCustomerParty.ContactElectronicMail <> '') then
        with AddChild('ram:DefinedTradeContact') do
        begin
          if (_Invoice.AccountingCustomerParty.ContactName <> '') then
            AddChild('ram:PersonName').Text := _Invoice.AccountingCustomerParty.ContactName;
          if (_Invoice.AccountingCustomerParty.ContactTelephone <> '') then
            AddChild('ram:TelephoneUniversalCommunication').AddChild('ram:CompleteNumber').Text := _Invoice.AccountingCustomerParty.ContactTelephone;
          if (_Invoice.AccountingCustomerParty.ContactElectronicMail <> '') then
            AddChild('ram:EmailURIUniversalCommunication').AddChild('ram:URIID').Text := _Invoice.AccountingCustomerParty.ContactElectronicMail;
        end;
        with AddChild('ram:PostalTradeAddress') do
        begin
          AddChild('ram:PostcodeCode').Text := _Invoice.AccountingCustomerParty.Address.PostalZone;
          AddChild('ram:LineOne').Text := _Invoice.AccountingCustomerParty.Address.StreetName;
          if _Invoice.AccountingCustomerParty.Address.AdditionalStreetName <> '' then
            AddChild('ram:LineTwo').Text := _Invoice.AccountingCustomerParty.Address.AdditionalStreetName;
          if _Invoice.AccountingCustomerParty.Address.AddressLine <> '' then
            AddChild('ram:LineThree').Text := _Invoice.AccountingCustomerParty.Address.AddressLine;
          AddChild('ram:CityName').Text := _Invoice.AccountingCustomerParty.Address.City;
          AddChild('ram:CountryID').Text := _Invoice.AccountingCustomerParty.Address.CountryCode;
          if _Invoice.AccountingCustomerParty.Address.CountrySubentity <> '' then
            AddChild('ram:CountrySubDivisionName').Text := _Invoice.AccountingCustomerParty.Address.CountrySubentity;
        end;
        if _Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyer <> '' then
        with AddChild('ram:URIUniversalCommunication').AddChild('ram:URIID') do
        begin
          Attributes['schemeID'] := 'EM';
          Text := _Invoice.AccountingCustomerParty.ElectronicAddressSellerBuyer;
        end;
        if _Invoice.AccountingCustomerParty.VATCompanyID <> '' then
        with AddChild('ram:SpecifiedTaxRegistration').AddChild('ram:ID') do
        begin
          Attributes['schemeID'] := 'VA';
          Text := _Invoice.AccountingCustomerParty.VATCompanyID;
        end;
        if _Invoice.AccountingCustomerParty.VATCompanyNumber <> '' then
        with AddChild('ram:SpecifiedTaxRegistration').AddChild('ram:ID') do
        begin
          Attributes['schemeID'] := 'FC';
          Text := _Invoice.AccountingCustomerParty.VATCompanyNumber;
        end;
      end;
      if _Invoice.SellerOrderReference <> '' then
        AddChild('ram:SellerOrderReferencedDocument').AddChild('ram:IssuerAssignedID').Text := _Invoice.SellerOrderReference;
      if _Invoice.PurchaseOrderReference <> '' then
        AddChild('ram:BuyerOrderReferencedDocument').AddChild('ram:IssuerAssignedID').Text := _Invoice.PurchaseOrderReference;
      if _Invoice.ContractDocumentReference <> '' then
        AddChild('ram:ContractReferencedDocument').AddChild('ram:IssuerAssignedID').Text := _Invoice.ContractDocumentReference;
      if _Invoice.ProjectReference <> '' then
      for i := 0 to _Invoice.Attachments.Count -1 do
      begin
        with AddChild('ram:AdditionalReferencedDocument') do
        begin
          AddChild('ram:IssuerAssignedID').Text := _Invoice.Attachments[i].ID;
          if _Invoice.Attachments[i].ExternalReference <> '' then
            AddChild('ram:URIID').Text := _Invoice.Attachments[i].ExternalReference;
          AddChild('ram:TypeCode').Text := '916';
          if _Invoice.Attachments[i].DocumentDescription <> '' then
            AddChild('ram:Name').Text := _Invoice.Attachments[i].DocumentDescription;
          if _Invoice.Attachments[i].ExternalReference = '' then
          with AddChild('ram:AttachmentBinaryObject') do
          begin
            Attributes['mimeCode'] := TXRechnungHelper.InvoiceAttachmentTypeToStr(_Invoice.Attachments[i].AttachmentType);
            Attributes['filename'] := _Invoice.Attachments[i].Filename;
            Text := _Invoice.Attachments[i].GetDataAsBase64;
          end;
        end;
      end;
      if not _Invoice.ProjectReference.IsEmpty then
      with AddChild('ram:SpecifiedProcuringProject') do
      begin
        AddChild('ram:ID').Text := _Invoice.ProjectReference;
        AddChild('ram:Name').Text := 'Project reference';
      end;
    end;
    with AddChild('ram:ApplicableHeaderTradeDelivery') do
    begin
      if (_Invoice.DeliveryInformation.Address.CountryCode <> '') or
         (_Invoice.DeliveryInformation.Name <> '') then
      begin
        with AddChild('ram:ShipToTradeParty') do
        begin
          AddChild('ram:Name').Text := _Invoice.DeliveryInformation.Name;
          with AddChild('ram:PostalTradeAddress') do
          begin
            AddChild('ram:PostcodeCode').Text := _Invoice.DeliveryInformation.Address.PostalZone;
            AddChild('ram:LineOne').Text := _Invoice.DeliveryInformation.Address.StreetName;
            if _Invoice.DeliveryInformation.Address.AdditionalStreetName <> '' then
              AddChild('ram:LineTwo').Text := _Invoice.DeliveryInformation.Address.AdditionalStreetName;
            if _Invoice.DeliveryInformation.Address.AddressLine <> '' then
              AddChild('ram:LineThree').Text := _Invoice.DeliveryInformation.Address.AddressLine;
            AddChild('ram:CityName').Text := _Invoice.DeliveryInformation.Address.City;
            AddChild('ram:CountryID').Text := _Invoice.DeliveryInformation.Address.CountryCode;
            if _Invoice.DeliveryInformation.Address.CountrySubentity <> '' then
              AddChild('ram:CountrySubDivisionName').Text := _Invoice.DeliveryInformation.Address.CountrySubentity;
          end;
        end;
      end;
      if (_Invoice.DeliveryInformation.ActualDeliveryDate > 0) then
      with AddChild('ram:ActualDeliverySupplyChainEvent')
           .AddChild('ram:OccurrenceDateTime')
           .AddChild('udt:DateTimeString') do
      begin
        Attributes['format'] := '102';
        Text := TXRechnungHelper.DateToStrUNCEFACTFormat(_Invoice.DeliveryInformation.ActualDeliveryDate);
      end;
      if _Invoice.DeliveryReceiptNumber <> '' then
      with AddChild('ram:DeliveryNoteReferencedDocument')
           .AddChild('ram:IssuerAssignedID') do
      begin
        Text := _Invoice.DeliveryReceiptNumber;
      end;
    end;
    with AddChild('ram:ApplicableHeaderTradeSettlement') do
    begin
      if _Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier <> '' then
        AddChild('ram:CreditorReferenceID').Text := _Invoice.AccountingSupplierParty.BankAssignedCreditorIdentifier;
      if _Invoice.PaymentID <> '' then
        AddChild('ram:PaymentReference').Text := _Invoice.PaymentID;
      //zuviel AddChild('ram:TaxCurrencyCode').Text := _Invoice.TaxCurrencyCode;
      AddChild('ram:InvoiceCurrencyCode').Text := _Invoice.InvoiceCurrencyCode;
      with AddChild('ram:SpecifiedTradeSettlementPaymentMeans') do
      begin
        AddChild('ram:TypeCode').Text := TXRechnungHelper.InvoicePaymentMeansCodeToStr(_Invoice.PaymentMeansCode);
        if (_Invoice.PaymentFinancialAccount <> '') then
        begin
          if _Invoice.PaymentMeansCode = ipmc_SEPADirectDebit then
          begin
            with AddChild('ram:PayerPartyDebtorFinancialAccount') do
              AddChild('ram:IBANID').Text := _Invoice.PaymentFinancialAccount;
          end else
          begin
            with AddChild('ram:PayeePartyCreditorFinancialAccount') do
            begin
              AddChild('ram:IBANID').Text := _Invoice.PaymentFinancialAccount;
              if _Invoice.PaymentFinancialAccountName <> '' then
                AddChild('ram:AccountName').Text := _Invoice.PaymentFinancialAccountName;
            end;
            if _Invoice.PaymentFinancialInstitutionBranch <> '' then
            with AddChild('ram:PayeeSpecifiedCreditorFinancialInstitution') do
              AddChild('ram:BICID').Text := _Invoice.PaymentFinancialInstitutionBranch;
          end;
        end;
      end;
      for taxSubtotal in _Invoice.TaxAmountSubtotals do
      with AddChild('ram:ApplicableTradeTax') do
      begin
        AddChild('ram:CalculatedAmount').Text := TXRechnungHelper.AmountToStr(taxSubtotal.TaxAmount);
        AddChild('ram:TypeCode').Text := 'VAT';
        if taxSubtotal.TaxExemptionReason <> '' then
          AddChild('ram:ExemptionReason').Text := taxSubtotal.TaxExemptionReason;
        AddChild('ram:BasisAmount').Text := TXRechnungHelper.AmountToStr(taxSubtotal.TaxableAmount);
        AddChild('ram:CategoryCode').Text := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeToStr(taxSubtotal.TaxCategory);
        AddChild('ram:RateApplicablePercent').Text := TXRechnungHelper.PercentageToStr(taxSubtotal.TaxPercent);
      end;
      if (_Invoice.InvoicePeriodStartDate > 100) and (_Invoice.InvoicePeriodEndDate > 100) then
      with AddChild('ram:BillingSpecifiedPeriod') do
      begin
        with AddChild('ram:StartDateTime').AddChild('udt:DateTimeString') do
        begin
          Attributes['format'] := '102';
          Text := TXRechnungHelper.DateToStrUNCEFACTFormat(_Invoice.InvoicePeriodStartDate);
        end;
        with AddChild('ram:EndDateTime').AddChild('udt:DateTimeString') do
        begin
          Attributes['format'] := '102';
          Text := TXRechnungHelper.DateToStrUNCEFACTFormat(_Invoice.InvoicePeriodEndDate);
        end;
      end;
      for allowanceCharge in _Invoice.AllowanceCharges do
      with AddChild('ram:SpecifiedTradeAllowanceCharge') do
      begin
        AddChild('ram:ChargeIndicator').AddChild('udt:Indicator').Text := LowerCase(BoolToStr(allowanceCharge.ChargeIndicator,true));
        if allowanceCharge.MultiplierFactorNumeric <> 0 then
          AddChild('ram:CalculationPercent').Text := TXRechnungHelper.FloatToStr(allowanceCharge.MultiplierFactorNumeric);
        if allowanceCharge.BaseAmount <> 0 then
          AddChild('ram:BasisAmount').Text := TXRechnungHelper.AmountToStr(allowanceCharge.BaseAmount);
        AddChild('ram:ActualAmount').Text := TXRechnungHelper.AmountToStr(allowanceCharge.Amount);
        AddChild('ram:ReasonCode').Text :=
                 IfThen(allowanceCharge.ChargeIndicator,
                 TXRechnungHelper.InvoiceSpecialServiceDescriptionCodeToStr(allowanceCharge.ReasonCodeCharge),
                 TXRechnungHelper.InvoiceAllowanceOrChargeIdentCodeToStr(allowanceCharge.ReasonCodeAllowance));
        if not allowanceCharge.Reason.IsEmpty then
          AddChild('ram:Reason').Text := allowanceCharge.Reason;
        with AddChild('ram:CategoryTradeTax') do
        begin
          AddChild('ram:TypeCode').Text := 'VAT';
          AddChild('ram:CategoryCode').Text := TXRechnungHelper.InvoiceDutyTaxFeeCategoryCodeToStr(allowanceCharge.TaxCategory);
          AddChild('ram:RateApplicablePercent').Text := TXRechnungHelper.PercentageToStr(allowanceCharge.TaxPercent);
        end;
      end;
      with AddChild('ram:SpecifiedTradePaymentTerms') do
      begin
        case _Invoice.PaymentTermsType of
          iptt_Net: if _Invoice.PaymentTermNetNote <> '' then
            AddChild('ram:Description').Text := System.StrUtils.ReplaceText(_Invoice.PaymentTermNetNote,'#',' ');
          iptt_CashDiscount1:
            AddChild('ram:Description').Text := Format('#SKONTO#TAGE=%d#PROZENT=%s#',
                [_Invoice.PaymentTermCashDiscount1Days,
                 TXRechnungHelper.FloatToStr(_Invoice.PaymentTermCashDiscount1Percent)])+
                IfThen(_Invoice.PaymentTermCashDiscount1Base <> 0,'BASISBETRAG='+
                  TXRechnungHelper.AmountToStr(_Invoice.PaymentTermCashDiscount1Base)+'#','')+
                #13#10;
          iptt_CashDiscount2:
          begin
            AddChild('ram:Description').Text := Format('#SKONTO#TAGE=%d#PROZENT=%s#',
                [_Invoice.PaymentTermCashDiscount1Days,
                 TXRechnungHelper.FloatToStr(_Invoice.PaymentTermCashDiscount1Percent)])+
                IfThen(_Invoice.PaymentTermCashDiscount1Base <> 0,'BASISBETRAG='+
                  TXRechnungHelper.AmountToStr(_Invoice.PaymentTermCashDiscount1Base)+'#','')+
                #13#10+
                Format('#SKONTO#TAGE=%d#PROZENT=%s#',
                [_Invoice.PaymentTermCashDiscount2Days,
                 TXRechnungHelper.FloatToStr(_Invoice.PaymentTermCashDiscount2Percent)])+
                IfThen(_Invoice.PaymentTermCashDiscount2Base <> 0,'BASISBETRAG='+
                  TXRechnungHelper.AmountToStr(_Invoice.PaymentTermCashDiscount2Base)+'#','')+
                #13#10;
            end;
        end;
        if _Invoice.InvoiceDueDate > 100 then
        with AddChild('ram:DueDateDateTime').AddChild('udt:DateTimeString') do
        begin
          Attributes['format'] := '102';
          Text := TXRechnungHelper.DateToStrUNCEFACTFormat(_Invoice.InvoiceDueDate);
        end;
        if _Invoice.PaymentMandateID <> '' then
          AddChild('ram:DirectDebitMandateID').Text := _Invoice.PaymentMandateID;
      end;
      with AddChild('ram:SpecifiedTradeSettlementHeaderMonetarySummation') do
      begin
        AddChild('ram:LineTotalAmount').Text := TXRechnungHelper.AmountToStr(_Invoice.LineAmount);
        AddChild('ram:ChargeTotalAmount').Text :=  TXRechnungHelper.AmountToStr(_Invoice.ChargeTotalAmount);
        AddChild('ram:AllowanceTotalAmount').Text := TXRechnungHelper.AmountToStr(_Invoice.AllowanceTotalAmount);
        AddChild('ram:TaxBasisTotalAmount').Text := TXRechnungHelper.AmountToStr(_Invoice.TaxExclusiveAmount);
        with AddChild('ram:TaxTotalAmount') do
        begin
          Attributes['currencyID'] := _Invoice.TaxCurrencyCode;
          Text :=  TXRechnungHelper.AmountToStr(_Invoice.TaxAmountTotal);
        end;
        //        <ram:RoundingAmount>0</ram:RoundingAmount>
        AddChild('ram:GrandTotalAmount').Text := TXRechnungHelper.AmountToStr(_Invoice.TaxInclusiveAmount);
        AddChild('ram:TotalPrepaidAmount').Text := TXRechnungHelper.AmountToStr(_Invoice.PrepaidAmount);
        AddChild('ram:DuePayableAmount').Text := TXRechnungHelper.AmountToStr(_Invoice.PayableAmount);
      end;
      for precedingInvoiceReference in _Invoice.PrecedingInvoiceReferences do
      with AddChild('ram:InvoiceReferencedDocument') do
      begin
        AddChild('ram:IssuerAssignedID').Text := precedingInvoiceReference.ID;
        with AddChild('ram:FormattedIssueDateTime').AddChild('qdt:DateTimeString') do
        begin
          Attributes['format'] := '102';
          Text := TXRechnungHelper.DateToStrUNCEFACTFormat(precedingInvoiceReference.IssueDate);
        end;
        break; //only one item allowed in cii
      end;

    end;
  end;
end;


end.

