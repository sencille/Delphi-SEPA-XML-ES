unit uDJMSepa1914XML;
{
https://github.com/cocosistemas/Delphi-SEPA-XML-ES
Diego J.Mu�oz. Freelance. Cocosistemas.com
}
//2016-01-15
//ver los pdfs de los bancos, con la norma.
//19.14 cobros. EL Ordenante COBRA AL DEUDOR

//Tenemos un array de Ordenantes (**cada uno con un IBAN de abono**), y para cada Ordenante
//un array con sus ordenes de cobro

{uso:
   - setInfoPresentador
   - A�adimos Ordenantes: addOrdenante (uno por cada cuenta de ingreso del cobro, donde nos pagan)
   - A�adimos los cobros: addCobro (uno por cada cobro, �l solo se coloca en su Ordenante,
     �ste ha tenido que ser a�adido previamente)
   - createfile (las ordenes estan en los arrays)
   - closefile
}

interface

uses System.Generics.Collections,
     senCille.CustomSEPA;

type
  //info de una orden de cobro (norma 19.14 xml)
  TsepaCollect = class {un Cobro}
    IdCobro         :string; //id unico cobro, ejemplo:20130930Fra.509301
    Importe         :Double;
    IdMandato       :string;
    DateOfSignature :TDateTime; //del mandato
    BIC             :string;
    NombreDeudor    :string;
    IBAN            :string;
    Concepto        :string;
  end;

  //TListOfCobros = array[1..5000] of TsepaCollection;

  //un conjunto de cobros por Ordenante, lo utilizamos por si utilizan
  //cobros a ingresar en diferentes cuentas (el <PmtInf> contiene la info del Ordenante, con su cuenta; y los
  //cobros relacionados con este Ordenante/cuenta de abono
  TsepaOrdenante = class {un Ordenante}
    PayMentId       :string; //Ejemplo: 2013-10-28_095831Remesa 218 UNICO POR Ordenante
    SumaImportes    :Double;
    NombreOrdenante :string;
    IBANOrdenante   :string;
    BICOrdenante    :string;
    IdOrdenante     :string; //el ID �nico del ordenante, normalmente dado por el banco
    Collects        :TList<TsepaCollect>;
    constructor Create;
    destructor Destroy; reintroduce;
  end;

  //TListOrdenantes = array[1..10] of TsepaOrdenante;

  TDJMNorma1914XML = class(TCustomSEPA) //el Ordenante cobra al DEUDOR
  private
    FOuputFile        :Text;
    FOrdenantes       :TList<TsepaOrdenante>; //Ordenantes, uno por cada cuenta de abono
    FdFileDate        :TDateTime;   //fecha del fichero

    FmTotalImportes     :Double;    //suma de los importes de los cobros
    FsNombrePresentador :string;    //nombre del presentador (el 'initiator')
    FsIdPresentador     :string;    //id presentador norma AT02
    FdOrdenesCobro      :TDateTime; //fecha del cargo en cuenta, PARA TODAS LAS ORDENES

    procedure WriteGroupHeader;
    procedure WriteOrdenesCobro(AOrdenante :TsepaOrdenante);
    procedure WriteDirectDebitOperationInfo(ACollection :TsepaCollect);

    procedure WriteInfoMandato(sIdMandato :string; dDateOfSignature :TDateTime);
    procedure WriteIdentificacionOrdenante(sIdOrdenanteAux :string);

    function CalculateNumOperaciones:Integer;
  public
    constructor Create;
    destructor Destroy; reintroduce;
    {$Message Warn 'Integrar esto en el Constructor'}
    procedure SetInfoPresentador(dFileDate          :TDateTime;
                                 sNombrePresentador :string;
                                 sIdPresentador     :string;
                                 dOrdenesCobro      :TDateTime);
    {$Message Warn 'Pasar una instancia en vez de los par�metros'}
    procedure AddOrdenante(APayMentId       :string;
                           ANombreOrdenante :string;
                           AIBANOrdenante   :string;
                           ABICOrdenante    :string;
                           AIdOrdenante     :string);

    {$Message Warn 'Pasar una instancia en vez de los par�metros'}
    procedure AddCobro(AIdCobro         :string; //id unico cobro, ejemplo:20130930Fra.509301
                       AImporte         :Double;
                       AIdMandato       :string;
                       ADateOfSignature :TDateTime; //del mandato
                       ABIC             :string;
                       ANombreDeudor    :string;
                       AIBAN            :string;
                       AConcepto        :string;
                       AIBANOrdenante   :string); //el cobro lo colocamos en la info de su Ordenante, por la cuenta

    procedure CreateFile(AFileName :string);
    procedure CloseFile;
    function HayCobros:Boolean;

    property Ordenantes :TList<TsepaOrdenante> read FOrdenantes;
  end;

implementation
uses System.SysUtils, Dialogs;

constructor TDJMNorma1914XML.Create;
begin
   FOrdenantes         := TList<TsepaOrdenante>.Create; //Ordenantes, uno por cada cuenta de abono
   FdFileDate          := Now;
   FmTotalImportes     := 0;
   FsNombrePresentador := '';
   FsIdPresentador     := '';
   FdOrdenesCobro      := Now;
end;

destructor TDJMNorma1914XML.Destroy;
//var i :Integer;
//    j :Integer;
begin

 //  for i := 1 to FNumOrdenantes do begin
      //para cada Ordenante destruimos sus cobros
      {Not necessary yet, destroy the Collections}
      {for j := 1 to FlistOrdenantes[i].iCobros do begin
         FListOrdenantes[i].ListCobros[j].Free;
      end;}

      //FListOrdenantes[i].Free;
   //end;
   FOrdenantes.Free;
   inherited Destroy;
end;

procedure TDJMNorma1914XML.SetInfoPresentador;
begin
   FdFileDate          := dFileDate;
   FsNombrePresentador := sNombrePresentador;
   FsIdPresentador     := sIdPresentador;
   FdOrdenesCobro      := dOrdenesCobro;
   //FsPaymentId:=sPaymentId;

   //FsNombreOrdenante:=sNombreOrdenante;
   //FsIBANOrdenante:=sIBANOrdenante;
   //FsBICOrdenante:=sBICOrdenante;
end;

procedure TDJMNorma1914XML.WriteGroupHeader;
begin
   //1.0 Group Header Conjunto de caracter�sticas compartidas por todas las operaciones incluidas en el mensaje
   Writeln(FOuputFile, '<GrpHdr>');

   //1.1 MessageId Referencia asignada por la parte iniciadora y enviada a la siguiente
   //parte de la cadena para identificar el mensaje de forma inequ�voca
   Writeln(FOuputFile, '<MsgId>'+CleanStr(GenerateUUID)+'</MsgId>');

   //1.2 Fecha y hora cuando la parte iniciadora ha creado un (grupo de) instrucciones de pago
   //(con 'now' es suficiente)
   Writeln(FOuputFile, '<CreDtTm>'+FormatDateTimeXML(FdFileDate)+'</CreDtTm>');

   //1.6  N�mero de operaciones individuales que contiene el mensaje
   Writeln(FOuputFile, '<NbOfTxs>'+IntToStr(CalculateNumOperaciones)+'</NbOfTxs>');

   //1.7 Suma total de todos los importes individuales incluidos en el mensaje
   writeLn(FOuputFile, '<CtrlSum>'+FormatAmountXML(FmTotalImportes)+'</CtrlSum>');

   //1.8 Parte que presenta el mensaje. En el mensaje de presentaci�n, puede ser el �Ordenante� o �el presentador�
   Write(FOuputFile, '<InitgPty>');
       //Nombre de la parte
       WriteLn(FOuputFile, '<Nm>'+CleanStr(FsNombrePresentador, INITIATOR_NAME_MAX_LENGTH)+'</Nm>');

       //Para el sistema de adeudos SEPA se utilizar� exclusivamente la etiqueta �Otra� estructurada
       //seg�n lo definido en el ep�grafe �Identificador del presentador� de la secci�n 3.3
       WriteLn(FOuputFile, '<Id>');
       WriteLn(FOuputFile, '<OrgId>');
       WriteLn(FOuputFile, '<Othr>');
       WriteLn(FOuputFile, '<Id>'+FsIdPresentador+'</Id>');
       WriteLn(FOuputFile, '</Othr>');
       WriteLn(FOuputFile, '</OrgId>');
       WriteLn(FOuputFile, '</Id>');
   Writeln(FOuputFile,'</InitgPty>');

   Writeln(FOuputFile, '</GrpHdr>');
end;


procedure TDJMNorma1914XML.CreateFile(AFileName :string);
var Ordenante :TsepaOrdenante;
begin
   //FsFileName := AFileName;
   AssignFile(FOuputFile, AFileName);
   rewrite(FOuputFile);
   WriteLn(FOuputFile, '<?xml version="1.0" encoding="UTF-8"?>');

   WriteLn(FOuputFile,
   '<Document xmlns="urn:iso:std:iso:20022:tech:xsd:'+SCHEMA_19+'"'+
                     ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">');

   //MESSAGE ROOT. Identifica el tipo de mensaje: iniciaci�n de adeudos directos
   WriteLn(FOuputFile, '<CstmrDrctDbtInitn>');
   WriteGroupHeader;
   //la info de cada Ordenante
   for Ordenante in FOrdenantes do begin
      if Ordenante.Collects.Count > 0 then WriteOrdenesCobro(Ordenante);
   end;

   WriteLn(FOuputFile, '</CstmrDrctDbtInitn>');
   WriteLn(FOuputFile, '</Document>'         );
end;

procedure TDJMNorma1914XML.CloseFile;
begin
   Close(FOuputFile);
end;

procedure TDJMNorma1914XML.WriteOrdenesCobro(AOrdenante :TsepaOrdenante);
var Collect :TsepaCollect;
begin
   //2.0 1..n Conjunto de caracter�sticas que se aplican a la parte del Ordenante de
   //las operaciones de pago incluidas en el mensaje de iniciaci�n de adeudos directos
   WriteLn(FOuputFile, '<PmtInf>');

   //2.1 Referencia �nica, asignada por el presentador, para identificar inequ�vocamente
   //el bloque de informaci�n del pago dentro del mensaje
   WriteLn(FOuputFile, '<PmtInfId>'+CleanStr(AOrdenante.PaymentId)+'</PmtInfId>');

   //2.2 Especifica el medio de pago que se utiliza para mover los fondos.
   //Fijo a DD
   WriteLn(FOuputFile, '<PmtMtd>'+'DD'+'</PmtMtd>');

   //2.3 <BtchBookg> Info de apunte en cuenta, no lo ponemos

   //2.4 <NbOfTxs> N� DE OPERACIONES, NO LO PONEMOS
   //writeLn(FOuputFile, '<NbOfTxs>'+IntToStr(NbOfTxs)+'</NbOfTxs>');

   //2.5 Suma total de todos los importes individuales incluidos en el bloque �Informaci�n del pago�,
   //sin tener en cuenta la divisa de los importes. No lo ponemos
   //writeLn(FOuputFile, '<CtrlSum>'+SEPAFormatAmount(oOrdenante.mSumaImportes)+'</CtrlSum>');

   //2.6 Informaci�n del tipo de pago
   WriteLn(FOuputFile, '<PmtTpInf>');

   //2.8 Nivel de servicio
   WriteLn(FOuputFile, '<SvcLvl>');
   //2.9 C�digo del nivel de servicio, fijo a 'SEPA'
   WriteLn(FOuputFile, '<Cd>'+'SEPA'+'</Cd>');
   Writeln(FOuputFile, '</SvcLvl>');

   //2.10 NO HAY

   //2.11 Instrumento espec�fico del esquema SEPA
   Write(FOuputFile, '<LclInstrm>');

   //2.12  Esquema bajo cuyas reglas ha de procesarse la operaci�n (AT-20), fijo a 'CORE'
   WriteLn(FOuputFile, '<Cd>'+'CORE'+'</Cd>');
   WriteLn(FOuputFile, '</LclInstrm>');

   //2.14  Secuencia del adeudo. Los dejamos todos en RCUR
   writeLn(FOuputFile, '<SeqTp>'+'RCUR'+'</SeqTp>');

   WriteLn(FOuputFile, '</PmtTpInf>');

   //2.18 Fecha de cobro: RequestedCollectionDate
   //Fecha solicitada por el Ordenante para realizar el cargo en la cuenta del deudor (AT-11)
   WriteLn(FOuputFile, '<ReqdColltnDt>'+FormatDateXML(FdOrdenesCobro)+'</ReqdColltnDt>');

   //2.19 Ordenante � Creditor
   WriteLn(FOuputFile, '<Cdtr><Nm>'+CleanStr(AOrdenante.NombreOrdenante, ORDENANTE_NAME_MAX_LENGTH)+'</Nm></Cdtr>');

   //2.20 Cuenta del Ordenante � CreditorAccount
   //Identificaci�n inequ�voca de la cuenta del Ordenante (AT-04)
   WriteLn(FOuputFile, '<CdtrAcct>');
   WriteAccountIdentification(FOuputFile, AOrdenante.IBANOrdenante);
   WriteLn(FOuputFile, '</CdtrAcct>');

   //2.21 Entidad del Ordenante � CreditorAgent
   //Entidad de cr�dito donde el Ordenante mantiene su cuenta.
   WriteLn(FOuputFile, '<CdtrAgt>');
   WriteBICInfo(FOuputFile, AOrdenante.BICOrdenante);
   WriteLn(FOuputFile, '</CdtrAgt>');

   //2.24 Cl�usula de gastos � ChargeBearer
   //Especifica qu� parte(s) correr�(n) con los costes asociados al tratamiento de la operaci�n de pago
   //Fijo a 'SLEV'
   WriteLn(FOuputFile, '<ChrgBr>'+'SLEV'+'</ChrgBr>');


   //2.27 Identificaci�n del Ordenante � CreditorSchemeIdentification
   WriteIdentificacionOrdenante(AOrdenante.IdOrdenante);

   //2.28 1..n Informaci�n de la operaci�n de adeudo directo � DirectDebitTransactionInformation
   for Collect in AOrdenante.Collects do begin
      WriteDirectDebitOperationInfo(Collect);
   end;

   WriteLn(FOuputFile, '</PmtInf>');
end;

procedure TDJMNorma1914XML.WriteDirectDebitOperationInfo(ACollection :TsepaCollect);
begin
   //2.28 1..n Informaci�n de la operaci�n de adeudo directo � DirectDebitTransactionInformation
   WriteLn(FOuputFile,  '<DrctDbtTxInf>');

   //2.29 Identificaci�n del pago � PaymentIdentification
   WriteLn(FOuputFile, '<PmtId>');
   //2.31 Identificaci�n de extremo a extremo � EndToEndIdentification
   //Identificaci�n �nica asignada por la parte iniciadora para identificar inequ�vocamente
   //cada operaci�n (AT-10). Esta referencia se transmite de extremo a extremo,
   //sin cambios, a lo largo de toda la cadena de pago
   Writeln(FOuputFile, '<EndToEndId>'+CleanStr(ACollection.IdCobro)+'</EndToEndId>');
   Writeln(FOuputFile, '</PmtId>');

   //2.44 Importe ordenado � InstructedAmount
   WriteLn(FOuputFile,  '<InstdAmt Ccy="'+'EUR'+'">'+FormatAmountXML(ACollection.Importe)+'</InstdAmt>');

   //2.46 Operaci�n de adeudo directo � DirectDebitTransaction
   //Conjunto de elementos que suministran informaci�n espec�fica relativa al mandato de adeudo directo
   WriteLn(FOuputFile,  '<DrctDbtTx>');
   WriteInfoMandato(ACollection.IdMandato, ACollection.DateOfSignature);
   WriteLn(FOuputFile,  '</DrctDbtTx>');

   //2.66 Identificaci�n del Ordenante � CreditorSchemeIdentification
   //es como el 2.27. No lo ponemos porque ya ponemos el 2.27
   //writeIdentificacionOrdenante(sIdOrdenanteAux);

   //2.70 Entidad del deudor � DebtorAgent
   WriteLn(FOuputFile,  '<DbtrAgt>');
   WriteBICInfo(FOuputFile, ACollection.BIC);
   WriteLn(FOuputFile,  '</DbtrAgt>');

   //2.72 Deudor � Debtor
   WriteLn(FOuputFile,  '<Dbtr><Nm>'+CleanStr(ACollection.NombreDeudor, DEUDOR_NAME_MAX_LENGTH)+'</Nm></Dbtr>');

   //2.73 Cuenta del deudor � DebtorAccount
   WriteLn(FOuputFile,  '<DbtrAcct>');
   WriteAccountIdentification(FOuputFile, ACollection.IBAN);
   WriteLn(FOuputFile,  '</DbtrAcct>');

   {
   if UltmtDbtrNm <> '' then
     //2.74 �ltimo deudor � UltimateDebtor
     WriteLn(FOuputFile,  '<UltmtDbtr><Nm>'+uSEPA_CleanStr(UltmtDbtrNm, DBTR_NM_MAX_LEN)+'</Nm></UltmtDbtr>');
   }

   //2.88 Concepto � RemittanceInformation
   //Informaci�n que opcionalmente remite el Ordenante al deudor para permitirle conciliar el pago
   //con la informaci�n comercial del mismo (AT-22).
   WriteLn(FOuputFile,  '<RmtInf><Ustrd>'+CleanStr(ACollection.Concepto, RMTINF_MAX_LENGTH)+'</Ustrd></RmtInf>');

   WriteLn(FOuputFile,  '</DrctDbtTxInf>');
end;

procedure TDJMNorma1914XML.writeInfoMandato;
begin
   //2.47 Informaci�n del mandato � MandateRelatedInformation
   WriteLn(FOuputFile, '<MndtRltdInf>');
   //2.48 Identificaci�n del mandato � MandateIdentification.
   //Por ejemplo un n� o algo as�
   WriteLn(FOuputFile, '<MndtId>'+CleanStr(sIdMandato, MNDTID_MAX_LENGTH)+'</MndtId>');
   //2.49 Fecha de firma � DateOfSignature
   WriteLn(FOuputFile, '<DtOfSgntr>'+FormatDateXML(dDateOfSignature)+'</DtOfSgntr>');
   //2.50 Indicador de modificaci�n � AmendmentIndicator
   WriteLn(FOuputFile, '<AmdmntInd>'+'false'+'</AmdmntInd>');
   {
   if AmdmntInd 'es True' then
     //escribir la info completa de la etiqueta <AmdmntInfDtls>
   }
   WriteLn(FOuputFile, '</MndtRltdInf>');
end;

procedure TDJMNorma1914XML.AddCobro(AIdCobro         :string; //id unico cobro, ejemplo:20130930Fra.509301
                                    AImporte         :Double;
                                    AIdMandato       :string;
                                    ADateOfSignature :TDateTime; //del mandato
                                    ABIC             :string;
                                    ANombreDeudor    :string;
                                    AIBAN            :string;
                                    AConcepto        :string;
                                    AIBANOrdenante   :string); //el cobro lo colocamos en la info de su Ordenante, por la cuenta
var Found         :Integer;
    i             :Integer;
    NewCollection :TsepaCollect;
begin
   //localizar en la lista de Ordenantes el iban, a�adirlo en los cobros de ese Ordenante
   Found := -1;
   for i := 0 to FOrdenantes.Count-1 do begin
      if FOrdenantes[i].IBANOrdenante = AIBANOrdenante then begin
         Found := i;
      end;
   end;

   if Found = -1 then begin
      ShowMessage('No se encontr� Ordenante para el IBAN: '+AIBANOrdenante);
      Exit;
   end;

   if FOrdenantes[Found].Collects.Count = 5000 then begin
      ShowMessage('No admitimos m�s de 5000 cobros por Ordenante');
      Exit;
   end;

   //hemos encontrado el Ordenante con ese IBAN, a�adimos un cobro
   NewCollection := TsepaCollect.Create;
   NewCollection.IdCobro         := AIdCobro;
   NewCollection.Importe         := AImporte;
   NewCollection.IdMandato       := AIdMandato;
   NewCollection.DateOfSignature := ADateOfSignature;
   NewCollection.BIC             := ABIC;
   NewCollection.NombreDeudor    := ANombreDeudor;
   NewCollection.IBAN            := Trim(AIBAN);
   NewCollection.Concepto        := AConcepto;

   FOrdenantes[Found].Collects.Add(NewCollection);
   FOrdenantes[Found].SumaImportes := FOrdenantes[Found].SumaImportes + AImporte;
   FmTotalImportes                 := FmTotalImportes + AImporte;
end;

procedure TDJMNorma1914XML.AddOrdenante(APayMentId, ANombreOrdenante, AIBANOrdenante, ABICOrdenante, AIdOrdenante :string);
var Found  :Boolean;
    i      :Integer;
    NewOrdenante :TsepaOrdenante;
begin
   if FOrdenantes.Count >= 10 then begin
      ShowMessage('Solamente se admiten como m�ximo 10 Ordenantes');
      Exit;
   end;

   //si ya hay uno con esa cuenta, no lo a�adimos
   Found := False;
   for i := 0 to FOrdenantes.Count-1 do begin
      if FOrdenantes[i].IBANOrdenante = AIBANOrdenante then Found := True;
   end;

   if not Found then begin
      NewOrdenante := TsepaOrdenante.Create;
      NewOrdenante.SumaImportes    := 0;
      NewOrdenante.PayMentId       := APayMentId;
      NewOrdenante.NombreOrdenante := ANombreOrdenante;
      NewOrdenante.IBANOrdenante   := AIBANOrdenante;
      NewOrdenante.BICOrdenante    := ABICOrdenante;
      NewOrdenante.IdOrdenante     := AIdOrdenante;
      FOrdenantes.Add(NewOrdenante);
   end;
end;

function TDJMNorma1914XML.CalculateNumOperaciones:Integer;
var i :TsepaOrdenante;
begin
   Result := 0;
   for i in FOrdenantes do begin
      Result := Result + i.Collects.Count;
   end;
end;

function TDJMNorma1914XML.HayCobros;
begin
   Result := FmTotalImportes <> 0;
end;

procedure TDJMNorma1914XML.writeIdentificacionOrdenante;
begin
   WriteLn(FOuputFile, '<CdtrSchmeId>');
   WriteLn(FOuputFile, '<Id>'         );
   WriteLn(FOuputFile, '<PrvtId>'     );
   WriteLn(FOuputFile, '<Othr>'       );
   WriteLn(FOuputFile, '<Id>' + CleanStr(sIdOrdenanteAux) + '</Id>');
   WriteLn(FOuputFile, '<SchmeNm><Prtry>SEPA</Prtry></SchmeNm>');
   WriteLn(FOuputFile, '</Othr>'       );
   WriteLn(FOuputFile, '</PrvtId>'     );
   WriteLn(FOuputFile, '</Id>'         );
   writeLn(FOuputFile, '</CdtrSchmeId>');
end;

{ TsepaOrdenante }

constructor TsepaOrdenante.Create;
begin
   inherited;
   Collects := TList<TsepaCollect>.Create;
end;

destructor TsepaOrdenante.Destroy;
begin
   Collects.Free;
   inherited;
end;

end.
