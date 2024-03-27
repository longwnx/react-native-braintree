#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <PassKit/PassKit.h>

@interface RNBraintreeApplePay : RCTEventEmitter <RCTBridgeModule, PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, strong) PKPaymentRequest *currentPaymentRequest;
@property (nonatomic, strong) PKPaymentAuthorizationViewController *paymentController;
@property (nonatomic, copy) void (^shippingContactCompletion)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull);
@property (nonatomic, copy) void (^shippingMethodCompletion)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull);
@property (strong, nonatomic) NSArray<PKShippingMethod *> *currentShippingMethods;
@property (nonatomic, strong) NSDecimalNumber *amount;
@property (nonatomic, strong) NSString *companyName;

@end
