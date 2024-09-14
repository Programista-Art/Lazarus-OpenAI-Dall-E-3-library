unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, imagegenerator,
  StdCtrls, ExtCtrls, ExtDlgs, Menus, BCExpandPanels, BCPanel, BCListBox,
  fphttpclient, FPImage, opensslsockets, FPReadJPEG, FPWriteJPEG, FPReadPNG,
  FileUtil, fpjson, jsonparser;

type

  { TDalee3 }

  TDalee3 = class(TForm)
    BCPanel2: TBCPanel;
    BCPanel3: TBCPanel;
    BCPanel6: TBCPanel;
    ButGenerateImg: TButton;
    ComboBoxStyle: TComboBox;
    ComboBoxSize: TComboBox;
    ComboBoxQuality: TComboBox;
    EditToken: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    LabelInfo: TLabel;
    Label7: TLabel;
    PanelBoczny: TBCPanel;
    ButDeleteImg: TButton;
    Buttsave: TButton;
    Image1: TImage;
    Label1: TLabel;
    MemoPrompt: TMemo;
    Panel1: TPanel;
    Panel2: TPanel;
    SPD: TSavePictureDialog;
    procedure ButGenerateImgClick(Sender: TObject);
    procedure ButDeleteImgClick(Sender: TObject);
    procedure ButtsaveClick(Sender: TObject);
    procedure DisplayImageInComponent(const ImageURL: String; ImageControl: TImage);
    procedure DownloadAndDisplayImage(const URL: string; Image: TImage);
    procedure ImageGenerationCompleted(Sender: TObject);
  private

  public

  end;

var
  Dalee3: TDalee3;

implementation

{$R *.lfm}

{ TDalee3 }



procedure TDalee3.ButGenerateImgClick(Sender: TObject);
var
  ImageGenerator: TImageGenerator;
  Prompt: String;
  ImageThread: TImageGenerationThread;
  ApiToken: String;
begin
  ApiToken := EditToken.Text;
  Image1.Picture.Clear;
  Prompt := MemoPrompt.Text;
  if ApiToken = '' then
  begin
    ShowMessage('Enter API Token');
  end
  else
  begin
  //We create an image generator object with an API key
  ImageGenerator := TImageGenerator.Create(ApiToken);
  try
    //We take values from ComboBoxes and assign them to properties
    ImageGenerator.Size := ComboBoxSize.Items[ComboBoxSize.ItemIndex];
    ImageGenerator.Quality := ComboBoxQuality.Items[ComboBoxQuality.ItemIndex];
    ImageGenerator.Style := ComboBoxStyle.Items[ComboBoxStyle.ItemIndex];

    //We create and run a thread to generate images
    ImageThread := TImageGenerationThread.Create(ImageGenerator, Prompt, @ImageGenerationCompleted);
    ImageThread.Start;

    //User notification about generation start
    LabelInfo.Caption := 'Generating image. Please wait... ';
    //Buttons
    ButGenerateImg.Enabled := False;
    ButDeleteImg.Enabled := False;
    Buttsave.Enabled := False;
  except
    ImageGenerator.Free;
    raise;
  end;
  end;
end;

procedure TDalee3.ButDeleteImgClick(Sender: TObject);
begin
  Image1.Picture.Clear;
end;


procedure TDalee3.ButtsaveClick(Sender: TObject);
begin
  if SPD.Execute then
  begin
      if not Image1.Picture.Graphic.Empty then
      begin
        Image1.Picture.SaveToFile(SPD.FileName);
        ShowMessage('The image was saved successfully!');
      end
      else
      begin
        ShowMessage('There is no image to save.');
      end;
    end;
  end;


procedure TDalee3.DisplayImageInComponent(const ImageURL: String;
  ImageControl: TImage);
var
  HttpClient: TFPHttpClient;
  ImageStream: TMemoryStream;
  Picture: TPicture;
begin
  HttpClient := TFPHttpClient.Create(nil);
  ImageStream := TMemoryStream.Create;
  Picture := TPicture.Create;
  try
    //Download image from URL and load it into memory stream
    HttpClient.Get(ImageURL, ImageStream);
    //Set stream position to start
    ImageStream.Position := 0;
    //Load image into TPicture
    try
      Picture.LoadFromStream(ImageStream);
    except
      on E: Exception do
      begin
        ShowMessage('Could not load image: ' + E.Message);
        Exit;
      end;
    end;

    //Assign an image to the TImage component
    ImageControl.Picture.Assign(Picture);
  finally
    HttpClient.Free;
    ImageStream.Free;
    Picture.Free;
  end;
end;


procedure TDalee3.DownloadAndDisplayImage(const URL: string; Image: TImage);
var
  HttpClient: TFPHttpClient;
  ImageStream: TMemoryStream;
begin
  HttpClient := TFPHttpClient.Create(nil);
  ImageStream := TMemoryStream.Create;
  try
    HttpClient.Get(URL, ImageStream);
    ImageStream.Position := 0;
    Image.Picture.LoadFromStream(ImageStream);
  finally
    ImageStream.Free;
    HttpClient.Free;
  end;
end;

procedure TDalee3.ImageGenerationCompleted(Sender: TObject);
var
  ImageThread: TImageGenerationThread;
begin
    ImageThread := TImageGenerationThread(Sender);

  if ImageThread.ImageURLs.Count > 0 then
  begin
    try
      DisplayImageInComponent(ImageThread.ImageURLs[0], Image1);
      LabelInfo.Caption := 'Image generated';
      //Buttons
      ButGenerateImg.Enabled := True;
      ButDeleteImg.Enabled := True;
      Buttsave.Enabled := True;
    except
      on E: Exception do
      begin
        ShowMessage('Failed to load image: ' + E.Message);
      end;
    end;
  end
  else
  begin
    ShowMessage('Failed to generate image');
  end;
end;





end.

