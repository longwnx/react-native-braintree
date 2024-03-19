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

// Private methods
- (NSArray *_Nonnull)getSupportedNetworksFromMethodData:(NSDictionary *_Nonnull)methodData;
- (NSArray<PKPaymentSummaryItem *> *_Nonnull)getPaymentSummaryItemsFromDetails:(NSDictionary *_Nonnull)details;
- (NSArray<PKShippingMethod *> *_Nonnull)getShippingMethodsFromDetails:(NSDictionary *_Nonnull)details;
- (PKPaymentSummaryItem *_Nonnull)convertDisplayItemToPaymentSummaryItem:(NSDictionary *_Nonnull)displayItem;
- (PKShippingMethod *_Nonnull)convertShippingOptionToShippingMethod:(NSDictionary *_Nonnull)shippingOption;
@end
