


# express - beta
Simple REST Framework 

[![](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=X658UEM4KQ3YA)

###Getting Started
Requires
 - **[X-Superobject](https://github.com/onryldz/x-superobject) Framework**

Assuming you've already installed **expres** framework, create a WebBroker - Web Server Application to your project *(File -> New -> Other -> WebBroker -> Web Server Application)*.

The following code must be inserted in the "WebModule.pas" which is automatically generated in the "DefaultHandlerAction" event.

```pascal
uses Express;
...
procedure TWebModule1.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  App.Call(Request, Response);
end;
```

###Samples

```pascal
unit Test;

interface

uses Express;

type
  TContent = record // or class
    Name: String;
    SurName: String;
  end;
  
  TResult = record // or class
    Success: Boolean;
  end;
  
  [Location('api/test')] // this optional
  TTest = class(TProvider)
  public
    [GET] [DEFAULT] // default attribute is optional. 
    function Multiply(A, B: Integer): Integer;  

    [GET]
    function Divide(A, B: Integer): Integer; 
    
    [DELETE] [DEFAULT] // default attribute is optional.
    function Del(Id: Integer): TResult;
    
    [POST] [DEFAULT] // default attribute is optional.
    function Insert(Id: Integer; Content: TContent): TResult; // Content is optional
    
    [PUT] [DEFAULT] // default attribute is optional.
    function Update(Id: Integer; Content: TContent): TResult; // Content is Optional
  end;
  
****

initialization
  TClassManager.Register(TTest);  
```

### OR
```pascal
unit Test;

interface

uses SysUtils, Express;

initialization

App.Get('api/test/multiply/:a/:b', procedure(Req: TRequest; Res: TResponse)
begin
  Res.Send(Req.Params['a'].toInteger * Req.Params['b'].ToInteger);
end));

// ***
// * The default attribute is like this route
// ***
App.Get('api/test/:a/:b', procedure(Req: TRequest; Res: TResponse)
begin
  Res.Send(Req.Params['a'].toInteger * Req.Params['b'].ToInteger);
end));

App.Del('api/test/del/:id', procedure(Req: TRequest; Res: TResponse) 
var
  Result: TResult;
begin
  Result.Success := Req.Params['id'].toInteger = 1;
  Res.SendRecord<TResult>(Result);
end));

App.Post('api/test/insert/:id', procedure(Req: TRequest; Res: TResponse) 
var
  Content: TContent;
  Result: TResult;
begin
  Content := TSuperRecord<TContent>.FromJSON(Req.WebRequest.Content);
  Result := Content.Name = 'Onur';
  Res.SendRecord<TResult>(Result);
end));

App.Put('api/test/update/:id', procedure(Req: TRequest; Res: TResponse) 
var
  Content: TContent;
  Result: TResult;
begin
  Content := TSuperRecord<TContent>.FromJSON(Req.WebRequest.Content);
  Result := Content.Name = 'YILDIZ';
  Res.SendRecord<TResult>(Result);
end));

```

### Aspec Oriented Programming

```pascal
unit AOPTest;

interface

uses Express;

type

  [Location('api/test')]
  TTest = class(TInject)
  public
    [GET]
    function Multiply(A, B: Integer): Integer;
  end;
  
****

initialization
  TClassManager.Register(TTest);  
```

### OR

```pascal
unit AOPTest;

interface

uses SysUtils, Express;

initialization

App.Use(hmGet, 'api', procedure(Req: TRequest; Res: TResponse; var Next: Boolean)
begin
  Next := False;
  Res.Send('Unauthorized (route)');
end));

App.Use(hmGet, 'api/test/multiply', procedure(Req: TRequest; Res: TResponse; var Next: Boolean)
begin
  Next := False;
  Res.Send('Unauthorized (method)');
end));

App.Use(hmGet, 'api/test/multiply/:a/:b', procedure(Req: TRequest; Res: TResponse; var Next: Boolean)
begin
  Next := Req.Params['a'].toInteger = 1;
  Res.Send('Unauthorized (method paremeter)');
end));

```
