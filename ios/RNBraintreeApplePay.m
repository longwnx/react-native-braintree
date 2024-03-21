@import PassKit;
#import "RNBraintreeApplePay.h"
#import "BraintreeCore.h"
#import "BTDataCollector.h"
#import "BraintreePaymentFlow.h"
#import "BraintreeApplePay.h"
#import <React/RCTEventEmitter.h>

@interface RNBraintreeApplePay()<PKPaymentAuthorizationViewControllerDelegate>

@property (nonatomic, strong) BTAPIClient *apiClient;
@property (nonatomic, strong) BTDataCollector *dataCollector;
@property (nonatomic, strong) RCTPromiseResolveBlock resolve;
@property (nonatomic, strong) RCTPromiseRejectBlock reject;
@property (nonatomic, assign) BOOL isApplePaymentAuthorized;

@end

@implementation RNBraintreeApplePay

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onShippingAddressUpdated", @"onShippingOptionChange", @"onUserAccept"];
}

RCT_EXPORT_MODULE()

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isApplePayAvailable) {
    BOOL canMakePayments = [PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:
            @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex, PKPaymentNetworkDiscover]];
    return [NSNumber numberWithBool:canMakePayments];
}

RCT_EXPORT_METHOD(runApplePay: (NSDictionary *)options
                     resolver: (RCTPromiseResolveBlock)resolve
                     rejecter: (RCTPromiseRejectBlock)reject) {
    NSString *companyName = options[@"companyName"];
    NSString *amount = options[@"amount"];
    NSString *clientToken = options[@"clientToken"];
    NSString *currencyCode = options[@"currencyCode"];
    if (!companyName) {
        reject(@"NO_COMPANY_NAME", @"You must provide a `companyName`", nil);
        return;
    }
    if (!amount) {
        reject(@"NO_TOTAL_PRICE", @"You must provide a `amount`", nil);
        return;
    }

    NSArray *shippingMethodsArray = options[@"shippingMethods"];
    NSMutableArray *shippingMethods = [NSMutableArray array];

    for (NSDictionary *methodDict in shippingMethodsArray) {
        PKShippingMethod *shippingMethod = [[PKShippingMethod alloc] init];
        shippingMethod.label = methodDict[@"label"];
        shippingMethod.amount = [NSDecimalNumber decimalNumberWithString:methodDict[@"amount"]];
        shippingMethod.detail = methodDict[@"detail"];
        shippingMethod.identifier = methodDict[@"identifier"];
        [shippingMethods addObject:shippingMethod];
    }



    self.apiClient = [[BTAPIClient alloc] initWithAuthorization: clientToken];
    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:self.apiClient];
    self.amount = [NSDecimalNumber decimalNumberWithString:amount];

    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAPIClient: self.apiClient];

    [applePayClient paymentRequest:^(PKPaymentRequest * _Nullable paymentRequest, NSError * _Nullable error) {
        if (error) {
            reject(@"APPLE_PAY_PAYMENT_REQUEST_FAILED", error.localizedDescription, nil);
            return;
        }

        if (@available(iOS 11.0, *)) {
            paymentRequest.requiredBillingContactFields = [NSSet setWithObject:PKContactFieldPostalAddress];
            paymentRequest.requiredShippingContactFields = [NSSet setWithObjects:PKContactFieldPostalAddress, PKContactFieldName, PKContactFieldEmailAddress, PKContactFieldPhoneNumber, nil];
        }
        self.currentPaymentRequest = paymentRequest;
        self.paymentController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:paymentRequest];
        paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
        paymentRequest.paymentSummaryItems = @[
            [PKPaymentSummaryItem summaryItemWithLabel:companyName amount:[NSDecimalNumber decimalNumberWithString:amount]]
        ];
        paymentRequest.currencyCode = currencyCode;
        paymentRequest.shippingMethods = shippingMethods;

        self.resolve = resolve;
        self.reject = reject;
        [self setIsApplePaymentAuthorized:NO];
        PKPaymentAuthorizationViewController *paymentController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:paymentRequest];
        paymentController.delegate = self;
        self.paymentController.delegate = self;
        [[self reactRoot] presentViewController:paymentController animated:YES completion:NULL];
    }];
}


- (void)handleTokenizationResult: (BTApplePayCardNonce *)tokenizedApplePayPayment
                           error: (NSError *)error
                         payment:(PKPayment *)payment
                      completion: (void (^)(PKPaymentAuthorizationStatus))completion{
    if (!tokenizedApplePayPayment && self.reject) {
        self.reject(error.localizedDescription, error.localizedDescription, error);
        completion(PKPaymentAuthorizationStatusFailure);
        [self resetPaymentResolvers];
        return;
    }
    [self.dataCollector collectDeviceData:^(NSString * _Nonnull deviceData) {
        if (self.resolve) {
            NSMutableDictionary *paymentResponse = [[NSMutableDictionary alloc]initWithCapacity:6];

            NSString *paymentData = [[NSString alloc] initWithData:payment.token.paymentData encoding:NSUTF8StringEncoding];
            [paymentResponse setObject:paymentData forKey:@"paymentData"];

            if (payment.billingContact) {
                paymentResponse[@"billingContact"] = [self contactToString:payment.billingContact];
            }

            if (payment.shippingContact) {
                paymentResponse[@"shippingContact"] = [self contactToString:payment.shippingContact];
            }
            self.resolve(@{@"deviceData": deviceData,
                           @"nonce": tokenizedApplePayPayment.nonce,
                           @"paymentResponse": paymentResponse
            });
            completion(PKPaymentAuthorizationStatusSuccess);
            [self resetPaymentResolvers];
        }
    }];
}

- (void)resetPaymentResolvers {
    self.resolve = NULL;
    self.reject = NULL;
}

#pragma mark - PKPaymentAuthorizationViewControllerDelegate
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus))completion {
    [self setIsApplePaymentAuthorized: YES];
    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAPIClient:self.apiClient];
    [applePayClient tokenizeApplePayPayment:payment
                                 completion:^(BTApplePayCardNonce *tokenizedApplePayPayment, NSError *error) {
        [self handleTokenizationResult:tokenizedApplePayPayment error:error payment:payment completion:completion];
    }];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
    didSelectShippingContact:(PKContact *)contact
        completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> *, NSArray<PKPaymentSummaryItem *> *))completion {
    self.shippingContactCompletion = completion;
        CNPostalAddress *postalAddress = contact.postalAddress;
    NSString *namePrefix = contact.name.namePrefix ?: @"";
    NSString *givenName = contact.name.givenName ?: @"";
    NSString *middleName = contact.name.middleName ?: @"";
    NSString *familyName = contact.name.familyName ?: @"";
    NSString *nameSuffix = contact.name.nameSuffix ?: @"";
    NSString *nickname = contact.name.nickname ?: @"";
    NSString *street = contact.postalAddress.street ?: @"";
    NSString *subLocality = contact.postalAddress.subLocality ?: @"";
    NSString *city = contact.postalAddress.city ?: @"";
    NSString *subAdministrativeArea = contact.postalAddress.subAdministrativeArea ?: @"";
    NSString *state = contact.postalAddress.state ?: @"";
    NSString *postalCode = contact.postalAddress.postalCode ?: @"";
    NSString *country = contact.postalAddress.country ?: @"";
    NSString *ISOCountryCode = contact.postalAddress.ISOCountryCode ?: @"";
    NSString *phoneNumber = contact.phoneNumber.stringValue ?: @"";
    NSString *emailAddress = contact.emailAddress ?: @"";

    NSDictionary *contactDict = @{
            @"name" : @{
                    @"namePrefix" : namePrefix,
                    @"givenName" : givenName,
                    @"middleName" : middleName,
                    @"familyName" : familyName,
                    @"nameSuffix" : nameSuffix,
                    @"nickname" : nickname
            },
            @"postalAddress" : @{
                    @"street" : street,
                    @"subLocality" : subLocality,
                    @"city" : city,
                    @"subAdministrativeArea" : subAdministrativeArea,
                    @"state" : state,
                    @"postalCode" : postalCode,
                    @"country" : country,
                    @"ISOCountryCode" : ISOCountryCode
            },
            @"phoneNumber" : phoneNumber,
            @"emailAddress" : emailAddress
    };
    [self sendEventWithName:@"onShippingAddressUpdated" body:contactDict];
    [self setIsApplePaymentAuthorized: YES];
    completion(PKPaymentAuthorizationStatusSuccess, self.currentShippingMethods, self.currentPaymentRequest.paymentSummaryItems);
}

RCT_REMAP_METHOD(updateShippingOptionsWithDetails,
        details:(NSArray *)details
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject)
{
    NSMutableArray<PKShippingMethod *> *updatedShippingMethods = [NSMutableArray array];
    for (NSDictionary *detail in details) {
        PKShippingMethod *shippingMethod = [[PKShippingMethod alloc] init];
        shippingMethod.identifier = detail[@"identifier"];
        shippingMethod.detail = detail[@"detail"];
        shippingMethod.label = detail[@"label"];
        shippingMethod.amount = [NSDecimalNumber decimalNumberWithString:detail[@"amount"]];

        [updatedShippingMethods addObject:shippingMethod];
    }

    self.currentShippingMethods = updatedShippingMethods;

    NSDictionary *result = @{
            @"message": @"Updated Success!",
            @"data": details
    };
    resolve(result);
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> *))completion {

    NSDecimalNumber *productAmount = self.amount;// self.amount là giá trị được lưu trữ từ options[@"amount"]

    NSDecimalNumber *shippingCost = shippingMethod.amount;

    NSDecimalNumber *totalAmount = [productAmount decimalNumberByAdding:shippingCost];

    NSArray<PKPaymentSummaryItem *> *updatedPaymentSummaryItems = @[
            [PKPaymentSummaryItem summaryItemWithLabel:@"Product total" amount:productAmount],
            [PKPaymentSummaryItem summaryItemWithLabel:shippingMethod.label amount:shippingCost],
            [PKPaymentSummaryItem summaryItemWithLabel:@"Total" amount:totalAmount]
    ];

    NSDictionary *option = @{
        @"selectedShippingOptionId": shippingMethod.identifier
    };

    [self sendEventWithName:@"onShippingOptionChange" body:option];

    completion(PKPaymentAuthorizationStatusSuccess, updatedPaymentSummaryItems);
}


- (void)paymentAuthorizationViewControllerDidFinish:(nonnull PKPaymentAuthorizationViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:NULL];
    if (self.reject && [self isApplePaymentAuthorized]) {
        self.reject(@"APPLE_PAY_FAILED", @"Apple Pay failed", nil);
    }
    if (self.isApplePaymentAuthorized == NO) {
        self.reject(@"USER_CANCELLATION", @"The user cancelled", nil);
    }
    [self resetPaymentResolvers];
    self.isApplePaymentAuthorized = NULL;
}

#pragma mark - Private method
- (NSString *_Nonnull)contactToString:(PKContact *_Nonnull)contact
{
    NSString *namePrefix = contact.name.namePrefix ?: @"";
    NSString *givenName = contact.name.givenName ?: @"";
    NSString *middleName = contact.name.middleName ?: @"";
    NSString *familyName = contact.name.familyName ?: @"";
    NSString *nameSuffix = contact.name.nameSuffix ?: @"";
    NSString *nickname = contact.name.nickname ?: @"";
    NSString *street = contact.postalAddress.street ?: @"";
    NSString *subLocality = contact.postalAddress.subLocality ?: @"";
    NSString *city = contact.postalAddress.city ?: @"";
    NSString *subAdministrativeArea = contact.postalAddress.subAdministrativeArea ?: @"";
    NSString *state = contact.postalAddress.state ?: @"";
    NSString *postalCode = contact.postalAddress.postalCode ?: @"";
    NSString *country = contact.postalAddress.country ?: @"";
    NSString *ISOCountryCode = contact.postalAddress.ISOCountryCode ?: @"";
    NSString *phoneNumber = contact.phoneNumber.stringValue ?: @"";
    NSString *emailAddress = contact.emailAddress ?: @"";

    NSDictionary *contactDict = @{
            @"name" : @{
                    @"namePrefix" : namePrefix,
                    @"givenName" : givenName,
                    @"middleName" : middleName,
                    @"familyName" : familyName,
                    @"nameSuffix" : nameSuffix,
                    @"nickname" : nickname
            },
            @"postalAddress" : @{
                    @"street" : street,
                    @"subLocality" : subLocality,
                    @"city" : city,
                    @"subAdministrativeArea" : subAdministrativeArea,
                    @"state" : state,
                    @"postalCode" : postalCode,
                    @"country" : country,
                    @"ISOCountryCode" : ISOCountryCode
            },
            @"phoneNumber" : phoneNumber,
            @"emailAddress" : emailAddress
    };

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:contactDict options:0 error:&error];

    if (!jsonData) {
        return @"";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}

#pragma mark - RootController
- (UIViewController*)reactRoot {
    UIViewController *topViewController  = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

@end
