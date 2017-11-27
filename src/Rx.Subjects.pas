(*
  ���������� �������� Observable.

  ������ ��� ������� ������� � ���������� ������������ Observable,
  ��������� ����.

  --- ������� �������������� ---

  C��������� ��������, ������� ����� ���� �� �������� � ����.
  ���� �� ��������� ����������� � ���, ��� �� ���� ������� �� ����� ������
  ����� ����, ��� ������������������ ��������� (onError ��� onCompleted).
  ���������� subject� ������� ��� ��������.

  ������������ �� ����� ���� ������������� �����, ��� ������������ Rx,
  ������� ��� ����� ���� ������������� � �� �������� ���� �������,
  ��� ��� ��� ����� �������� � �������������� ������������.
*)
unit Rx.Subjects;

interface
uses Rx, Rx.Implementations, Generics.Collections;

type

  ///	<summary>
  ///	  C���� ������� ���������� Subject. ����� ������ ���������� �
  ///	  PublishSubject, �� ������ �� ���� �����������, ������� ��������� ��
  ///	  ���� � ������ ������.
  ///	</summary>
  TPublishSubject<T> = class(TObservableImpl<T>)
  public
    procedure OnNext(const Data: T); override;
  end;

  ///	<summary>
  ///	  ����� ����������� ����������� ���������� ��� ����������� � ���� ������.
  ///	  ����� � ���� ���������� ����� ���������, ������������������ ������ ���
  ///	  ������� � ������. ��� ����������� ����������� ������ ����� ����������
  ///	  ����������� ��� ������.
  ///	</summary>
  TReplaySubject<T> = class(TPublishSubject<T>)
  type
    TValue = TSmartVariable<T>;
    TVaueDescr = record
      Value: TValue;
      Stamp: TTime;
    end;
  strict private
    FCache: TList<TVaueDescr>;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create;

    ///	<summary>
    ///	  <para>
    ///	    ���������� �� ������ �� ������ ������ ����, ��� ���
    ///	    ������������������ ����� ���� �������� ��� ���� ������������.
    ///	  </para>
    ///	  <para>
    ///	    CreateWithSize ������������ ������ ������, �
    ///     CreateWithTime �����, ������� ������� ����� ���������� � ����.
    ///	  </para>
    ///	</summary>
    constructor CreateWithSize(Size: LongWord);
    constructor CreateWithTime(Time: LongWord;
      TimeUnit: LongWord = Rx.TimeUnit.MILLISECONDS; From: TDateTime=Rx.StdSchedulers.IMMEDIATE);
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
  end;


  ///	<summary>
  ///	  BehaviorSubject ������ ������ ��������� ��������. ��� �� �� �����, ���
  ///	  � ReplaySubject, �� � ������� �������� 1. �� ����� �������� ��� �����
  ///	  ���� ��������� ��������� ��������, ����� ������� ����������, ��� ������
  ///	  ������ ����� �������� ����� �����������.
  ///	</summary>
  TBehaviorSubject<T> = class(TPublishSubject<T>)
  strict private
    FValue: TSmartVariable<T>;
    FValueExists: Boolean;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create(const Value: T); overload;
    procedure OnNext(const Data: T); override;
  end;


  ///	<summary>
  ///	  ����� ������ ��������� ��������. ������� � ���, ��� �� �� ������ ������
  ///	  �� ��� ���� �� ���������� ������������������. ��� ����������, �����
  ///	  ����� ������ ������ �������� � ��� �� �����������.
  ///	</summary>
  TAsyncSubject<T> = class(TObservableImpl<T>)
  type
    TValue = TSmartVariable<T>;
  strict private
    FCache: TList<TValue>;
  protected
    property Cache: TList<TValue> read FCache;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
    procedure OnCompleted; override;
  end;

implementation
uses SysUtils, Rx.Schedulers;

{ TPublishSubject<T> }

procedure TPublishSubject<T>.OnNext(const Data: T);
var
  Contract: IContract;
  Ref: TSmartVariable<T>;
begin
  inherited;
  Ref := Data;
  if Supports(Scheduler, StdSchedulers.ICurrentThreadScheduler) then
    for Contract in Freeze do
      Contract.GetSubscriber.OnNext(TSmartVariable<T>.Create(Data))
  else
    for Contract in Freeze do
      Scheduler.Invoke(TOnNextAction<T>.Create(Data, Contract))
end;

{ TReplaySubject<T> }

constructor TReplaySubject<T>.Create;
begin
  FCache := TList<TVaueDescr>.Create;
end;

constructor TReplaySubject<T>.CreateWithSize(Size: LongWord);
begin
  Create;
end;

constructor TReplaySubject<T>.CreateWithTime(Time: LongWord; TimeUnit: LongWord;
  From: TDateTime);
begin
  Create;
end;

destructor TReplaySubject<T>.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TReplaySubject<T>.OnNext(const Data: T);
var
  Descr: TVaueDescr;
begin
  inherited OnNext(Data);
  Descr.Value := Data;
  Descr.Stamp := Now;
  FCache.Add(Descr);
end;

procedure TReplaySubject<T>.OnSubscribe(Subscriber: ISubscriber<T>);
var
  Descr: TVaueDescr;
begin
  inherited;
  for Descr in FCache do
    Subscriber.OnNext(Descr.Value);
end;

{ TBehaviorSubject<T> }

constructor TBehaviorSubject<T>.Create(const Value: T);
begin
  inherited Create;
  FValue := Value;
  FValueExists := True;
end;

procedure TBehaviorSubject<T>.OnNext(const Data: T);
begin
  inherited;
  FValue := Data;
  FValueExists := True;
end;

procedure TBehaviorSubject<T>.OnSubscribe(Subscriber: ISubscriber<T>);
begin
  inherited;
  if FValueExists then
    Subscriber.OnNext(FValue);
end;

{ TAsyncSubject<T> }

constructor TAsyncSubject<T>.Create;
begin
  inherited Create;
  FCache := TList<TValue>.Create;
end;

destructor TAsyncSubject<T>.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TAsyncSubject<T>.OnCompleted;
var
  Value: TValue;
  Contract: IContract;
begin
  if Supports(Scheduler, StdSchedulers.ICurrentThreadScheduler) then
    for Contract in Freeze do
      for Value in FCache do
        Contract.GetSubscriber.OnNext(Value)
  else
    for Contract in Freeze do
      for Value in FCache do
        Scheduler.Invoke(TOnNextAction<T>.Create(Value, Contract));
  inherited;
end;

procedure TAsyncSubject<T>.OnNext(const Data: T);
begin
  inherited;
  FCache.Add(Data);
end;

end.
