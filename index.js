// main index.js

import {NativeModules, Platform} from 'react-native';

const {RNBraintree} = NativeModules;
const {RNBraintreeApplePay} = NativeModules;

function updateShippingOptionsIfIOS(details) {
  if (Platform.OS === 'ios' && RNBraintreeApplePay) {
    RNBraintreeApplePay.updateShippingOptionsWithDetails(details);
  }
}


export default {
  showPayPalModule: RNBraintree.showPayPalModule,
  runGooglePay: RNBraintree.runGooglePay,
  run3DSecureCheck: RNBraintree.run3DSecureCheck,
  tokenizeCard: RNBraintree.tokenizeCard,
  runApplePay: RNBraintreeApplePay && RNBraintreeApplePay.runApplePay,
  requestPayPalBillingAgreement: RNBraintree.requestPayPalBillingAgreement,
  getDeviceData: RNBraintree.getDeviceData,
  updateShippingOptionsWithDetails: updateShippingOptionsIfIOS,
  isApplePayAvailable:RNBraintreeApplePay ? RNBraintreeApplePay.isApplePayAvailable : () => false,
};
