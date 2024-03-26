declare module '@longwnx/react-native-braintree' {
  export interface BraintreeResponse {
    nonce: string;
    deviceData: string;
    paymentResponse: {
      shippingContact: string;
      billingContact: string;
      paymentData: string
    }
  }

  export interface BraintreeOptions {
    clientToken: string;
    amount: string;
    currencyCode: string;
    shippingMethods: ShippingMethod[]
  }

  export interface Run3DSecureCheckOptions
    extends Omit<BraintreeOptions, 'currencyCode' | 'clientToken'> {
    nonce: string;
    /* Pass clientToken if previously no RNBraintree methods were run. */
    clientToken?: string;
    /* Provide as many of the following fields as possible. */
    email?: string;
    firstname?: string;
    lastname?: string;
    phoneNumber?: string;
    streetAddress?: string;
    streetAddress2?: string;
    city?: string;
    region?: string;
    postalCode?: string;
    countryCode?: string;
  }

  export interface TokenizeCardOptions {
    clientToken: string;
    number: string;
    expirationMonth: string;
    expirationYear: string;
    cvv: string;
    postalCode?: string;
  }

  export interface RunApplePayOptions extends BraintreeOptions {
    companyName: string;
  }

  export interface PayPalBillingAgreementOptions {
    clientToken: string;
    description?: string;
    localeCode?: string;
  }

  export interface ShippingMethod {
    label: string;
    detail: string;
    amount: string;
    identifier: string;
  }

  export interface PostalAddress {
    street: string;
    subLocality: string;
    city: string;
    postalCode: number | string;
    country: string;
    subAdministrativeArea: string;
    state: string;
    ISOCountryCode: string;
  }

  export interface ContactName {
    namePrefix: string;
    givenName: string;
    nameSuffix: string;
    middleName: string;
    familyName: string;
    nickname: string
  }

  export interface ShippingContact {
    emailAddress: string;
    postalAddress:  PostalAddress;
    name: ContactName;
  }

  export interface BillingContact {
    emailAddress: string;
    postalAddress:  PostalAddress;
    name: ContactName;
  }

  export interface PaymentResponse {
    deviceData: string;
    billingContact:  BillingContact;
    shippingContact: ShippingContact;
  }

  export interface ContactDict {
    name: ContactName;
    postalAddress:  PostalAddress;
    phoneNumber: string;
    emailAddress: string;
  }

  // Export

  interface RNBraintreeModule {
    showPayPalModule(options: BraintreeOptions): Promise<BraintreeResponse>;
    runGooglePay(options: BraintreeOptions): Promise<BraintreeResponse>;
    run3DSecureCheck(
      options: Run3DSecureCheckOptions,
    ): Promise<BraintreeResponse>;
    tokenizeCard(options: TokenizeCardOptions): Promise<BraintreeResponse>;
    runApplePay(options: RunApplePayOptions): Promise<BraintreeResponse>;
    requestPayPalBillingAgreement(
      options: PayPalBillingAgreementOptions,
    ): Promise<BraintreeResponse>;
    getDeviceData(clientToken: string): Promise<string>;
    updateShippingOptionsWithDetails(shippingMethods: ShippingMethod[]):  Promise<string>;
    isApplePayAvailable(): boolean;
  }

  const RNBraintree: RNBraintreeModule;

  export default RNBraintree;
}
