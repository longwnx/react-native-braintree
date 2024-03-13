#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <PassKit/PassKit.h>

@interface RNBraintreeApplePay : RCTEventEmitter <RCTBridgeModule, PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, strong) PKPaymentRequest *currentPaymentRequest;
@end
