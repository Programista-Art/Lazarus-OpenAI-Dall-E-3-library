{Library created by Programista Art
 E-mail: programista.art@gmail.com
 YouTube: https://www.youtube.com/@programistaart
 Shop: programista.art
 MIT License
}
unit ImageGenerator;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser;

type
  TImageGenerator = class
  private
    FToken: String;
    FModel: String;
    FSize: String;
    FQuality: String;
    FResponseFormat: String;
    FStyle: String;
    FUser: String;
    FNumImages: Integer;
    function GenerateImageRequestBody(const Prompt: String): String;
    function RequestImageGeneration(const RequestBody: String): String;
    function ExtractImageURLs(const JSON: String): TStringList;
  public
    constructor Create(Token: String);
    function GenerateImages(const Prompt: String): TStringList; // Returns list of image URLs or base64 JSON
    property Model: String read FModel write FModel;
    property Size: String read FSize write FSize;
    property Quality: String read FQuality write FQuality;
    property ResponseFormat: String read FResponseFormat write FResponseFormat;
    property Style: String read FStyle write FStyle;
    property User: String read FUser write FUser;
    property NumImages: Integer read FNumImages write FNumImages;
  end;

  TImageGenerationThread = class(TThread)
  private
    FImageGenerator: TImageGenerator;
    FPrompt: String;
    FImageURLs: TStringList;
    FErrorMsg: String;
    FOnCompletion: TNotifyEvent;
  protected
    procedure Execute; override;
    procedure DoCompletion;
  public
    constructor Create(ImageGenerator: TImageGenerator; const Prompt: String; OnCompletion: TNotifyEvent);
    property ImageURLs: TStringList read FImageURLs;
    property ErrorMsg: String read FErrorMsg;
  end;

implementation

constructor TImageGenerator.Create(Token: String);
begin
  FToken := Token;
  FModel := 'dall-e-3';
  FSize := '1024x1024';
  FQuality := 'standard';
  FResponseFormat := 'url';
  FStyle := 'vivid';
  FUser := '';
  FNumImages := 1; //By default it generates one image
end;

function TImageGenerator.GenerateImageRequestBody(const Prompt: String): String;
var
  JSONData: TJSONObject;
begin
  JSONData := TJSONObject.Create;
  try
    JSONData.Add('prompt', Prompt);
    JSONData.Add('model', FModel);
    JSONData.Add('size', FSize);
    JSONData.Add('quality', FQuality);
    JSONData.Add('response_format', FResponseFormat);
    JSONData.Add('style', FStyle);
    JSONData.Add('n', FNumImages);
    if FUser <> '' then
      JSONData.Add('user', FUser);
    Result := JSONData.AsJSON;
  finally
    JSONData.Free;
  end;
end;

function TImageGenerator.RequestImageGeneration(const RequestBody: String): String;
var
  HttpClient: TFPHttpClient;
  Response: TStringStream;
  URL: String;
begin
  URL := 'https://api.openai.com/v1/images/generations';
  HttpClient := TFPHttpClient.Create(nil);
  Response := TStringStream.Create('');
  try
    HttpClient.AddHeader('Content-Type', 'application/json');
    HttpClient.AddHeader('Authorization', 'Bearer ' + FToken);
    HttpClient.RequestBody := TRawByteStringStream.Create(RequestBody);
    try
      HttpClient.Post(URL, Response);
      Result := Response.DataString;
    except
      on E: Exception do
        raise Exception.Create('Error requesting image generation: ' + E.Message);
    end;
  finally
    HttpClient.RequestBody.Free;
    HttpClient.Free;
    Response.Free;
  end;
end;

function TImageGenerator.ExtractImageURLs(const JSON: String): TStringList;
var
  Data: TJSONData;
  JSONObj: TJSONObject;
  ImageArray: TJSONArray;
  i: Integer;
  ImageURLs: TStringList;
begin
  ImageURLs := TStringList.Create;
  Data := GetJSON(JSON);
  try
    if Data.JSONType = jtObject then
    begin
      JSONObj := TJSONObject(Data);
      ImageArray := JSONObj.Arrays['data'];
      for i := 0 to ImageArray.Count - 1 do
      begin
        if FResponseFormat = 'url' then
          ImageURLs.Add(ImageArray.Objects[i].Get('url', ''))
        else if FResponseFormat = 'b64_json' then
          ImageURLs.Add(ImageArray.Objects[i].Get('b64_json', ''));
      end;
    end;
  finally
    Data.Free;
  end;
  Result := ImageURLs;
end;

function TImageGenerator.GenerateImages(const Prompt: String): TStringList;
var
  RequestBody: String;
  Response: String;
begin
  RequestBody := GenerateImageRequestBody(Prompt);
  Response := RequestImageGeneration(RequestBody);
  Result := ExtractImageURLs(Response);
end;

constructor TImageGenerationThread.Create(ImageGenerator: TImageGenerator; const Prompt: String; OnCompletion: TNotifyEvent);
begin
  inherited Create(True); //We are creating a thread in limbo
  FImageGenerator := ImageGenerator;
  FPrompt := Prompt;
  FOnCompletion := OnCompletion; //We store a reference to the event
  FreeOnTerminate := True; //Automatically release thread upon completion
  FImageURLs := TStringList.Create; //Initializing the URL list
end;

procedure TImageGenerationThread.Execute;
begin
  try
    FImageURLs := FImageGenerator.GenerateImages(FPrompt);
  except
    on E: Exception do
    begin
      FErrorMsg := 'Error in image generation: ' + E.Message;
    end;
  end;
  Synchronize(@DoCompletion); //Calling a method after the thread has ended
end;

procedure TImageGenerationThread.DoCompletion;
begin
  if Assigned(FOnCompletion) then
    FOnCompletion(Self);
end;

end.

