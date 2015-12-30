 (*
  *                       Express - Simple REST Framework
  *
  * The MIT License (MIT)
  * Copyright (c) 2015 Onur YILDIZ
  *
  *
  * Permission is hereby granted, free of charge, to any person
  * obtaining a copy of this software and associated documentation
  * files (the "Software"), to deal in the Software without restriction,
  * including without limitation the rights to use, copy, modify,
  * merge, publish, distribute, sublicense, and/or sell copies of the Software,
  * and to permit persons to whom the Software is furnished to do so,
  * subject to the following conditions:
  *
  * The above copyright notice and this permission notice shall
  * be included in all copies or substantial portions of the Software.
  *
  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
  * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
  * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
  * THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  *
  *)

unit Express;

interface

uses
  System.SysUtils,
  System.Classes,
  Generics.Collections,
  Generics.Defaults,
  Web.HTTPApp,
  System.Rtti,
  System.Variants,
  System.TypInfo,
  XSuperObject;

type
 (*
  * FORWARD DECL.
  *)
  TStaticRouteLevel = class;
  TDynamicRouteLevel = class;

 (*
  *  ATTRIBUTES
  *)

  THttpMethod = (hmGET, hmPUT, hmPOST, hmDELETE);

  TCustomHttpMethodAttribute = class abstract(TCustomAttribute)
  private
    FMethod: THttpMethod;
  public
    property Method: THttpMethod read FMethod;
  end;

  GET = class(TCustomHttpMethodAttribute)
  public
    constructor Create;
  end;

  PUT = class(TCustomHttpMethodAttribute)
  public
    constructor Create;
  end;

  POST = class(TCustomHttpMethodAttribute)
  public
    constructor Create;
  end;

  DELETE = class(TCustomHttpMethodAttribute)
    constructor Create;
  end;

  DEFAULT = class(TCustomAttribute)
  end;

  Location = class(TCustomAttribute)
  private
    FValue: String;
  public
    constructor Create(Value: String);
    property Value: String read FValue;
  end;


 (*
  * CLASSES
  *)

  TURIParameterKind = (pkStatic, pkDynamic);
  TURIParameter = class
  private
    FName: String;
    FKind: TURIParameterKind;
  public
    property Name: String read FName write FName;
    property Kind: TURIParameterKind read FKind write FKind;
  end;

  TURIInfo = class
  private
    FParams: TObjectList<TURIParameter>;
    FParamIndex: TDictionary<String, Integer>;
    FHttpMethod: THttpMethod;
    FDynamicCount: Integer;
  public
    constructor Create(Method: THttpMethod);
    destructor Destroy; override;
    procedure Add(const Name: String; Kind: TURIParameterKind);
    property ParamIndex: TDictionary<String, Integer> read FParamIndex;
    property Params: TObjectList<TURIParameter> read FParams;
    property Method: THttpMethod read FHttpMethod;
    class function Parse(Method: THttpMethod; const Value: String): TURIInfo;
  end;


  TParameters = TArray<String>;
  PParameters = ^TParameters;

  TRequest = class
  private
    FParams: PParameters;
    FURIInfo: TURIInfo;
    FWebRequest: TWebRequest;
    function GetParam(Key: String): String; inline;
  public
    constructor Create(URIInfo: TURIInfo; Parameters: PParameters; WebRequest: TWebRequest);
    property Params[Key: String]: String read GetParam;
    property WebRequest: TWebRequest read FWebRequest;
  end;

  TResponse = class
  private
    FResponse: TWebResponse;
    function GetContentType: String; inline;
    procedure SetContentType(const Value: String); inline;
  public
    constructor Create(Response: TWebResponse);
    procedure Send(const Data: String);
    procedure SendTValue(const Data: TValue);
    procedure SendRecord<T: record>(const Rec: T);
    procedure SendObject(Obj: TObject);
    property ContentType: String read GetContentType write SetContentType;
  end;

  TExecution = reference to procedure(Req: TRequest; Res: TResponse);
  TAOPExecution = reference to procedure(Req: TRequest; Res: TResponse; var Next: Boolean);
 (* Route Classes *)
  TRouteLevel = class
  private
    FParent: TRouteLevel;
    FStaticChilds: TObjectDictionary<String, TStaticRouteLevel>;
    FDynamicChilds: TDynamicRouteLevel;
    FHasDynamics: Boolean;
    FURIInfo: TURIInfo;
    FHandle: TExecution;
    FAOPHandle: TList<TAOPExecution>;
    procedure FreeAOPHandles;
  public
    constructor Create(Parent: TRouteLevel);
    destructor Destroy; override;
    function Next(Req: TRequest; Res: TResponse): Boolean;
    function GetOrCreateStaticChild(const Name: String): TStaticRouteLevel;
    function GetOrCreateDynamicChilds: TDynamicRouteLevel;
    function GetStaticChild(const Name: String): TStaticRouteLevel; inline;
    property Parent: TRouteLevel read FParent;
    property HasDynamics: Boolean read FHasDynamics;
    property DynamicChilds: TDynamicRouteLevel read FDynamicChilds;
    property URIInfo: TURIInfo read FURIInfo write FURIInfo;
    property Handle: TExecution read FHandle write FHandle;
    property AOPHandle: TList<TAOPExecution> read FAOPHandle;
  end;

  TStaticRouteLevel = class(TRouteLevel)
  private
    FName: String;
  public
    constructor Create(Parent: TRouteLevel; const Name: String);
    property Name: String read FName;
  end;

  TDynamicRouteLevel = class(TRouteLevel)
  end;

  TRouteManager = class
  private
    FRootLevels: Array [THttpMethod] of TRouteLevel;
    function _Add(Method: THttpMethod; const URI: String): TRouteLevel;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Method: THttpMethod; const URI: String; Handle: TExecution); inline;
    procedure AddUse(Method: THttpMethod; const URI: String; Handle: TAOPExecution); inline;
    function Resolve(Req: TWebRequest; Res: TWebResponse; Method: THttpMethod; URI: String; var Params: TArray<String>): TRouteLevel;
  end;

  TProvider = class
  end;
  TProviderClass = class of TProvider;

  TInject = class
  private
    FNext: Boolean;
    FRequest: TRequest;
    FResponse: TResponse;
  protected
    property Next: Boolean read FNext write FNext;
    property Request: TRequest read FRequest;
    property Response: TResponse read FResponse;
  end;
  TInjectClass = class of TInject;

  TClassManager = class
  private
    class var FProviderList:  TDictionary<String, TProviderClass>;
    class var FInjectList: TDictionary<String, TInjectClass>;
    class var FContext: TRttiContext;
    class function FindAttribute<T: TCustomAttribute>(Typ: TRttiType): T;
    class function FindAttributeMethod<T: TCustomAttribute>(Typ: TRttiMethod): T;
    class function FindAttributes<T: TCustomAttribute>(Typ: TRttiMethod): TList<T>;
    class function GetLocation(Typ: TRttiType; ProviderClass: TClass): String;
    class procedure RegisterMethods(Location: String; Typ: TRttiType);
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Register(ProviderClass: TProviderClass); overload;
    class procedure Register(InjectClass: TInjectClass); overload;
  end;

  TExpressApp = class
  private
    FRoutes: TRouteManager;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Use(Method: THttpMethod; const URI: String; Handle: TAOPExecution);
    procedure Get(const URI: String; Handle: TExecution);
    procedure Put(const URI: String; Handle: TExecution);
    procedure Post(const URI: String; Handle: TExecution);
    procedure Del(const URI: String; Handle: TExecution);

    procedure Call(Request: TWebRequest; Response: TWebResponse);
    property Routes: TRouteManager read FRoutes;
  end;

var
  App: TExpressApp;

implementation

type
  TContentParameter = (cpNone, cpRecord, cpClass);

{ TURIInfo }

procedure TURIInfo.Add(const Name: String; Kind: TURIParameterKind);
var
  Param: TURIParameter;
begin
  Param := TURIParameter.Create;
  Param.Name := Name;
  Param.Kind := Kind;
  FParams.Add(Param);
  if Kind = pkDynamic then begin
     FParamIndex.Add(Param.Name, FDynamicCount);
     Inc(FDynamicCount);
  end;
end;

constructor TURIInfo.Create;
begin
  FDynamicCount := 0;
  FParams := TObjectList<TURIParameter>.Create;
  FParamIndex := TDictionary<String, Integer>.Create(TEqualityComparer<String>.Construct(
                     function(const Left, Right: String): Boolean begin
                        Result := CompareText(Left, Right) = 0;
                     end,
                     function(const Value: String): Integer var S: String; begin
                        S := Value.ToLower;
                        Result := BobJenkinsHash(PChar(S)^, SizeOf(Char) * Length(S), 0)
                     end));
  FHttpMethod := Method;
end;

destructor TURIInfo.Destroy;
begin
  FParams.Free;
  FParamIndex.Free;
  inherited;
end;

class function TURIInfo.Parse(Method: THttpMethod; const Value: String): TURIInfo;
var
  Data: String;
begin
  Result := TURIInfo.Create(Method);
  try
    for Data in Value.Split(['/']) do begin
        if Data.Trim = '' then
           Continue;

        if Data[1] = ':' then
           Result.Add(Data.Substring(1), pkDynamic)
        else Result.Add(Data, pkStatic);
    end;
  except
    Result.Free;
    raise;
  end;
end;

{ TRouteLevel }

constructor TRouteLevel.Create(Parent: TRouteLevel);
begin
  FParent := Parent;
  FAOPHandle := TList<TAOPExecution>.Create;
  FStaticChilds := TObjectDictionary<String, TStaticRouteLevel>.Create([doOwnsValues], TEqualityComparer<String>.Construct(
                     function(const Left, Right: String): Boolean begin
                        Result := CompareText(Left, Right) = 0;
                     end,
                     function(const Value: String): Integer var S: String; begin
                        S := Value.ToLower;
                        Result := BobJenkinsHash(PChar(S)^, SizeOf(Char) * Length(S), 0)
                     end));
end;

destructor TRouteLevel.Destroy;
begin
  FStaticChilds.Free;
  FDynamicChilds.Free;
  FURIInfo.Free;
  FreeAOPHandles;
  inherited;
end;

procedure TRouteLevel.FreeAOPHandles;
{$IF CompilerVersion < 29}
var I: Integer;
{$ENDIF}
begin
  {$IF CompilerVersion < 29}
  for I := 0 to FAOPHandle.Count - 1 do
      FAOPHandle.List[I]._Release;
  {$ENDIF}
  FAOPHandle.Free;
end;

function TRouteLevel.GetOrCreateDynamicChilds: TDynamicRouteLevel;
begin
  if FDynamicChilds = Nil then begin
     FDynamicChilds := TDynamicRouteLevel.Create(Self);
     FHasDynamics := True;
  end;
  Result := FDynamicChilds;
end;

function TRouteLevel.GetOrCreateStaticChild(const Name: String): TStaticRouteLevel;
begin
  if not FStaticChilds.TryGetValue(Name, Result) then begin
     Result := TStaticRouteLevel.Create(Self, Name);
     FStaticChilds.Add(Name, Result);
  end;
end;

function TRouteLevel.GetStaticChild(const Name: String): TStaticRouteLevel;
begin
  if FStaticChilds.ContainsKey(Name) then
     Result := FStaticChilds[Name]
  else Result := Nil;
end;

function TRouteLevel.Next(Req: TRequest; Res: TResponse): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to FAOPHandle.Count - 1 do begin
      FAOPHandle[I](Req, Res, Result);
      if not Result then
         Exit(False);
  end;
end;

{ TStaticRouteLevel }

constructor TStaticRouteLevel.Create(Parent: TRouteLevel; const Name: String);
begin
  inherited Create(Parent);
  FName := Name;
end;

{ TRouteManager }

procedure TRouteManager.Add(Method: THttpMethod; const URI: String; Handle: TExecution);
begin
  _Add(Method, URI).Handle := Handle;
end;

procedure TRouteManager.AddUse(Method: THttpMethod; const URI: String; Handle: TAOPExecution);
begin
  _Add(Method, URI).AOPHandle.Add(Handle);
end;

constructor TRouteManager.Create;
var
  Level: THttpMethod;
begin
  for Level := Low(THttpMethod) to High(THttpMethod) do
      FRootLevels[Level] := TRouteLevel.Create(Nil);
end;

destructor TRouteManager.Destroy;
var
  Level: THttpMethod;
begin
  for Level := Low(THttpMethod) to High(THttpMethod) do
      FRootLevels[Level].Free;
  inherited;
end;

function TRouteManager.Resolve(Req: TWebRequest; Res: TWebResponse; Method: THttpMethod; URI: String; var Params: TArray<String>): TRouteLevel;
var
  Level: String;
  NextLevel: TRouteLevel;
  Parameters: TList<String>;

  function Next(Level: TRouteLevel): Boolean;
  var
    Request: TRequest;
    Response: TResponse;
  begin
    Params := Parameters.ToArray;
    Request := TRequest.Create(NextLevel.URIInfo, @Params, Req);
    Response := TResponse.Create(Res);
    try
      Result := Level.Next(Request, Response);
    finally
      Request.Free;
      Response.Free;
    end;
  end;

begin
  Result := Nil;
  Parameters := TList<String>.Create;
  try
    Result := FRootLevels[Method];
    if (URI <> '') and (URI[1] = '/') then URI := URI.Substring(1);
    for Level in URI.Split(['/']) do begin
        NextLevel := Result.GetStaticChild(Level);
        if NextLevel = Nil then begin
           if Result.HasDynamics then begin
              Result := Result.DynamicChilds;
              Parameters.Add(Level);
              if (Result.AOPHandle.Count > 0) and not Next(Result) then
                 Exit(Nil);
           end else begin
              Exit(Nil);
           end;

        end else begin
           if (NextLevel.AOPHandle.Count > 0) and not Next(NextLevel) then
               Exit(Nil);
           Result := NextLevel;
        end;
    end;
  finally
     if Result <> Nil then
        Params := Parameters.ToArray;
     Parameters.Free;
  end;
end;

function TRouteManager._Add(Method: THttpMethod; const URI: String): TRouteLevel;
var
  I: Integer;
  CurrLevel: TRouteLevel;
  Item: TURIParameter;
  Info: TURIInfo;
begin
  Result := Nil;
  Info := TURIInfo.Parse(Method, URI);
  try
    CurrLevel := FRootLevels[Info.Method];
    for I := 0 to Info.Params.Count - 1 do begin
        Item := Info.Params.List[I];
        if Item.Kind = pkStatic then
           CurrLevel := CurrLevel.GetOrCreateStaticChild(Item.Name)
        else CurrLevel := CurrLevel.GetOrCreateDynamicChilds;
    end;
    if not Assigned(Currlevel.URIInfo) then
       CurrLevel.URIInfo := Info
    else begin
       Info.Free;
       Info := Nil;
    end;
    Result := CurrLevel;
  except
    Info.Free;
  end;
end;

{ GET }

constructor GET.Create;
begin
  FMethod := hmGET;
end;

{ PUT }

constructor PUT.Create;
begin
  FMethod := hmPUT;
end;

{ POST }

constructor POST.Create;
begin
  FMethod := hmPOST;
end;

{ DELETE }

constructor DELETE.Create;
begin
  FMethod := hmDELETE;
end;

{ TExpressApp }

procedure TExpressApp.Call(Request: TWebRequest; Response: TWebResponse);
var
  Method: THttpMethod;
  Route: TRouteLevel;
  Params: TParameters;
  ExpRequest: TRequest;
  ExpResponse: TResponse;
begin
  if Request.Method = 'GET' then
     Method := hmGET
  else if Request.Method = 'POST' then
     Method := hmPOST
  else if Request.Method = 'DELETE' then
     Method := hmDELETE
  else if Request.Method = 'PUT' then
     Method := hmPUT
  else
     raise Exception.CreateFmt('Unknown Http Method: "%s"', [Request.Method]);

  Route := FRoutes.Resolve(Request, Response, Method, String(Request.PathInfo), Params);
  if Assigned(Route) and Assigned(Route.Handle) then begin
     ExpRequest := TRequest.Create(Route.URIInfo, @Params, Request);
     ExpResponse := TResponse.Create(Response);
     try
       Route.Handle(ExpRequest, ExpResponse);
     finally
       ExpRequest.Free;
       ExpResponse.Free;
     end;
  end;
end;

constructor TExpressApp.Create;
begin
  FRoutes := TRouteManager.Create;
end;

destructor TExpressApp.Destroy;
begin
  FRoutes.Free;
  inherited;
end;

procedure TExpressApp.Del(const URI: String; Handle: TExecution);
begin
  Routes.Add(hmDELETE, URI, Handle);
end;

procedure TExpressApp.Get(const URI: String; Handle: TExecution);
begin
  Routes.Add(hmGET, URI, Handle);
end;

procedure TExpressApp.Post(const URI: String; Handle: TExecution);
begin
  Routes.Add(hmPOST, URI, Handle);
end;

procedure TExpressApp.Put(const URI: String; Handle: TExecution);
begin
  Routes.Add(hmPUT, URI, Handle);
end;

procedure TExpressApp.Use(Method: THttpMethod; const URI: String; Handle: TAOPExecution);
begin
  Routes.AddUse(Method, URI, Handle);
end;

{ TRequest }

constructor TRequest.Create(URIInfo: TURIInfo; Parameters: PParameters; WebRequest: TWebRequest);
begin
  FURIInfo := URIInfo;
  FParams := Parameters;
  FWebRequest := WebRequest;
end;

function TRequest.GetParam(Key: String): String;
begin
  Result := FParams^[FURIInfo.ParamIndex[Key]];
end;

{ TResponse }

constructor TResponse.Create(Response: TWebResponse);
begin
  FResponse := Response;
  Self.GetInterfaceTable
end;

function TResponse.GetContentType: String;
begin
  Result := String(FResponse.ContentType)
end;

procedure TResponse.Send(const Data: String);
begin
  FResponse.Content := Data;
end;

procedure TResponse.SendObject(Obj: TObject);
begin
  Send(Obj.AsJSON(False, True));
end;

procedure TResponse.SendRecord<T>(const Rec: T);
begin
  Send(TSuperRecord<T>.AsJSON(Rec));
end;

procedure TResponse.SendTValue(const Data: TValue);
var
  Json: ISuperObject;
begin
  if Data.Kind = tkRecord then begin
     Json := TSuperObject.Create;
     TSerializeParse.ReadRecord(Data.TypeInfo, Data.GetReferenceToRawData, Json);
     Send(Json.AsJSON(False, True))
  end else
     Send(VarToStr(Data.AsVariant));
end;

procedure TResponse.SetContentType(const Value: String);
begin
  FResponse.ContentType := AnsiString(Value);
end;

{ TClassManager }

class constructor TClassManager.Create;
begin
  FProviderList :=  TDictionary<String, TProviderClass>.Create(TEqualityComparer<String>.Construct(
    function(const Left, Right: String): Boolean begin
       Result := CompareText(Left, Right) = 0;
    end,
    function(const Value: String): Integer var S: String; begin
       S := Value.ToLower;
       Result := BobJenkinsHash(PChar(S)^, SizeOf(Char) * Length(S), 0)
    end
  ));

  FInjectList := TDictionary<String, TInjectClass>.Create(TEqualityComparer<String>.Construct(
    function(const Left, Right: String): Boolean begin
       Result := CompareText(Left, Right) = 0;
    end,
    function(const Value: String): Integer var S: String; begin
       S := Value.ToLower;
       Result := BobJenkinsHash(PChar(S)^, SizeOf(Char) * Length(S), 0)
    end
  ));

  FContext := TRttiContext.Create;
end;

class destructor TClassManager.Destroy;
begin
  FProviderList.Free;
  FInjectList.Free;
  FContext.Free;
end;

class function TClassManager.FindAttribute<T>(Typ: TRttiType): T;
var
  Attr: TCustomAttribute;
begin
  for Attr in Typ.GetAttributes do begin
      if Attr.ClassType.ClassInfo = TypeInfo(T) then
         Exit(Attr as T);
  end;
  Result := Nil;
end;

class function TClassManager.FindAttributeMethod<T>(Typ: TRttiMethod): T;
var
  Attr: TCustomAttribute;
begin
  for Attr in Typ.GetAttributes do begin
      if Attr.ClassType.ClassInfo = TypeInfo(T) then
         Exit(Attr as T);
  end;
  Result := Nil;
end;


class function TClassManager.FindAttributes<T>(Typ: TRTTIMethod): TList<T>;
var
  Attr: TCustomAttribute;
begin
  Result := TList<T>.Create;
  try
    for Attr in Typ.GetAttributes do begin
      if Attr is T then
         Result.Add(T(Attr))
    end;
  except
    Result.Free;
    Result := Nil;
  end;
end;

class function TClassManager.GetLocation(Typ: TRttiType; ProviderClass: TClass): String;
var
  LocationAttribute: Location;
begin
  if Typ = Nil then
     Result := ProviderClass.ClassName
  else begin
     LocationAttribute := FindAttribute<Location>(Typ);
     if Assigned(LocationAttribute) then
        Result := LocationAttribute.Value
     else Result := ProviderClass.ClassName;
  end;
end;

class procedure TClassManager.Register(ProviderClass: TProviderClass);
var
  Typ: TRttiType;
  Location: String;
begin
  Typ := FContext.GetType(ProviderClass);
  Location := GetLocation(Typ, ProviderClass);
  FProviderList.Add(Location, ProviderClass);
  RegisterMethods(Location, Typ);
end;

type
  TClassDelegate = record
    Handle: TExecution;
    InjectHandle: TAOPExecution;
  end;

  TDelegateHelper = class
  public
    class function NewRecord(var Ptr: Pointer; TypInf: PTypeInfo; const Json: String): TValue; inline;
    class function NewObject(var Ptr: Pointer; TypInf: PTypeInfo; const Json: String): TValue; inline;
    class procedure Final(var Ptr: Pointer; Info: PTypeInfo); inline;
  end;

function ClassDelegate(Meta: TClass; Method: TRttiMethod; ContentParam: TContentParameter; Parameters: TArray<TRttiParameter>): TClassDelegate;
begin
  Result.InjectHandle := Nil;
  Result.Handle := procedure(Req: TRequest; Res: TResponse)
                     var
                       I: Integer;
                       Instance: TObject;
                       Values: TList<TValue>;
                       Parameter: TRttiParameter;
                       Return: TValue;
                       FreeInstance: TValue;
                       InstancePointer: Pointer;
                     begin
                       Values := TList<TValue>.Create;
                       Instance := Meta.Create;
                       TInject(Instance).FRequest := Req;
                       TInject(Instance).FResponse := Res;
                       try
                         for I := 0 to High(Parameters) do begin
                             Parameter := Parameters[I];
                             if (ContentParam <> cpNone) and (High(Parameters) = I) then begin
                                case ContentParam of
                                  cpRecord: begin
                                     FreeInstance := TDelegateHelper.NewRecord(InstancePointer, Parameter.ParamType.Handle, Req.WebRequest.Content);
                                     Values.Add(FreeInstance);
                                  end;
                                  cpClass: begin
                                     FreeInstance := TDelegateHelper.NewObject(InstancePointer, Parameter.ParamType.Handle, Req.WebRequest.Content);
                                     Values.Add(FreeInstance);
                                  end;
                                end;

                             end else begin

                                 case Parameter.ParamType.TypeKind of
                                   tkInteger:
                                      Values.Add( TValue.From<Integer>(StrToIntDef(Req.Params[Parameter.Name], 0)) );

                                   tkChar:
                                      Values.Add( TValue.From<Char>(Req.Params[Parameter.Name][1]) );

                                   tkEnumeration:
                                      Values.Add( TValue.FromOrdinal(Parameter.ParamType.Handle, StrToIntDef(Req.Params[Parameter.Name], 0)) );

                                   tkFloat:
                                      Values.Add( TValue.From<Double>(StrToFloatDef(Req.Params[Parameter.Name], 0)) );

                                   tkString, tkUString:
                                      Values.Add( TValue.From<String>(Req.Params[Parameter.Name]) );

                                   tkVariant:
                                      Values.Add( TValue.From<Variant>(Req.Params[Parameter.Name]) );

                                 end;
                             end;
                         end;

                          Return := Method.Invoke(Instance, Values.ToArray);
                          Res.SendTValue(Return);
                          if Return.IsObject then
                             Return.AsObject.Free;
                       finally
                         Values.Free;
                         Instance.Free;
                         if ContentParam <> cpNone then
                            TDelegateHelper.Final(InstancePointer, FreeInstance.TypeInfo);
                       end;
                     end;
end;


function InjectClassDelegate(Meta: TClass; Method: TRttiMethod; ContentParam: TContentParameter; Parameters: TArray<TRttiParameter>): TClassDelegate;
begin

  Result.Handle := Nil;
  Result.InjectHandle := procedure(Req: TRequest; Res: TResponse; var Next: Boolean)
                     var
                       I: Integer;
                       Instance: TObject;
                       Values: TList<TValue>;
                       Parameter: TRttiParameter;
                       Return: TValue;
                       FreeInstance: TValue;
                       InstancePointer: Pointer;
                     begin
                       Values := TList<TValue>.Create;
                       Instance := Meta.Create;
                       try
                         for I := 0 to High(Parameters) do begin
                             Parameter := Parameters[I];
                             if (ContentParam <> cpNone) and (High(Parameters) = I) then begin
                                case ContentParam of
                                  cpRecord: begin
                                     FreeInstance := TDelegateHelper.NewRecord(InstancePointer, Parameter.ParamType.Handle, Req.WebRequest.Content);
                                     Values.Add(FreeInstance);
                                  end;
                                  cpClass: begin
                                     FreeInstance := TDelegateHelper.NewObject(InstancePointer, Parameter.ParamType.Handle, Req.WebRequest.Content);
                                     Values.Add(FreeInstance);
                                  end;
                                end;

                             end else begin

                                 case Parameter.ParamType.TypeKind of
                                   tkInteger:
                                      Values.Add( TValue.From<Integer>(StrToIntDef(Req.Params[Parameter.Name], 0)) );

                                   tkChar:
                                      Values.Add( TValue.From<Char>(Req.Params[Parameter.Name][1]) );

                                   tkEnumeration:
                                      Values.Add( TValue.FromOrdinal(Parameter.ParamType.Handle, StrToIntDef(Req.Params[Parameter.Name], 0)) );

                                   tkFloat:
                                      Values.Add( TValue.From<Double>(StrToFloatDef(Req.Params[Parameter.Name], 0)) );

                                   tkString, tkUString:
                                      Values.Add( TValue.From<String>(Req.Params[Parameter.Name]) );

                                   tkVariant:
                                      Values.Add( TValue.From<Variant>(Req.Params[Parameter.Name]) );

                                 end;
                             end;
                         end;

                          Return := Method.Invoke(Instance, Values.ToArray);
                          Res.SendTValue(Return);
                          if Return.IsObject then
                             Return.AsObject.Free;

                          Next := TInject(Instance).Next;

                       finally
                         Values.Free;
                         Instance.Free;
                         if ContentParam <> cpNone then
                            TDelegateHelper.Final(InstancePointer, FreeInstance.TypeInfo);
                       end;
                     end;
end;

class procedure TClassManager.Register(InjectClass: TInjectClass);
var
  Typ: TRttiType;
  Location: String;
begin
  Typ := FContext.GetType(InjectClass);
  Location := GetLocation(Typ, InjectClass);
  FInjectList.Add(Location, InjectClass);
  RegisterMethods(Location, Typ);
end;

class procedure TClassManager.RegisterMethods(Location: String; Typ: TRttiType);
var
  I, J, ParamLen: Integer;
  Method: TRttiMethod;
  Parameter: TRttiParameter;
  MethodName, Params: String;
  AttrList: TList<TCustomHttpMethodAttribute>;
  Attr: TCustomHttpMethodAttribute;
  MetaClass: TClass;
  IsDefault: Boolean;
  MethodParameters: TArray<TRttiParameter>;
  ContentParam: TContentParameter;
  procedure AddMethod(const URI: String);
  var
    Delegate: TClassDelegate;
  begin
    if MetaClass.InheritsFrom(TProvider) then begin
       Delegate := ClassDelegate(MetaClass, Method, ContentParam, Method.GetParameters);
       App.Routes.Add(Attr.Method, URI, Delegate.Handle);
    end else begin
       Delegate := InjectClassDelegate(MetaClass, Method, ContentParam, Method.GetParameters);
       App.Routes.AddUse(Attr.Method, URI, Delegate.InjectHandle);
    end;
  end;
begin
  IsDefault := False;
  MetaClass := Typ.AsInstance.MetaclassType;
  for Method in Typ.GetMethods do begin
      AttrList := FindAttributes<TCustomHttpMethodAttribute>(Method);
      try
        if AttrList.Count > 0 then
           IsDefault := FindAttributeMethod<DEFAULT>(Method) <> Nil
        else Continue;

        MethodParameters := Method.GetParameters;
        ParamLen := High(MethodParameters);
        MethodName := Method.Name;
        if not Location.Trim.IsEmpty then
           MethodName := '/' + MethodName;

        for I := 0 to AttrList.Count - 1 do begin
            Attr := AttrList.List[I];
            Params := '';
            ContentParam := cpNone;
            for J := 0 to High(MethodParameters) do begin
                Parameter := MethodParameters[J];
                if (Attr.Method in [hmPUT, hmPOST]) and (J = ParamLen) then begin
                   if Parameter.ParamType.TypeKind = tkRecord  then
                      ContentParam := cpRecord
                   else if Parameter.ParamType.TypeKind = tkClass then
                      ContentParam := cpClass;
                   Continue;
                end;
                Params := Params + '/:' + Parameter.Name;
            end;

            AddMethod(Location + MethodName + Params);
            if IsDefault then
               AddMethod(Location + Params);
        end;
      finally
        AttrList.Free;
      end;
  end;
end;

{ Location }

constructor Location.Create(Value: String);
begin
  FValue := Value;
end;

{ TDelegateHelper }

class procedure TDelegateHelper.Final(var Ptr: Pointer; Info: PTypeInfo);
begin
  if Info.Kind = tkRecord then begin
     FinalizeArray(Ptr, Info, 1);
     FreeMem(Ptr, Info.TypeData.RecSize);

  end else begin
     TObject(Ptr).Free;
  end;
end;

class function TDelegateHelper.NewObject(var Ptr: Pointer; TypInf: PTypeInfo; const Json: String): TValue;
var
  Cls: TClass;
begin
  Cls := TypInf.TypeData.ClassType;
  Ptr := Cls.Create;
  try
    TSerializeParse.WriteObject(TObject(Ptr), SO(Json));
    TValue.Make(NativeInt(Ptr), TypInf, Result);
  except
    TObject(Ptr).Free;
    Ptr := Nil;
  end;
end;

class function TDelegateHelper.NewRecord(var Ptr: Pointer; TypInf: PTypeInfo; const Json: String): TValue;
var
  Size: Integer;
begin
  Size := TypInf.TypeData.RecSize;
  Ptr := AllocMem(Size);
  try
    TSerializeParse.WriteRecord(TypInf, Ptr, SO(Json));
    TValue.Make(Ptr, TypInf, Result);
  except
    FreeMem(Ptr, Size);
  end;
end;

initialization
   App := TExpressApp.Create;

finalization
   App.Free;

end.
