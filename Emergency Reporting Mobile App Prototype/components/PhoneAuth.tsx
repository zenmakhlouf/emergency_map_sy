import React, { useState } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { InputOTP, InputOTPGroup, InputOTPSlot } from './ui/input-otp';
import { ArrowLeft, Phone } from 'lucide-react';

interface PhoneAuthProps {
  userType: 'citizen' | 'responder';
  onAuthenticated: () => void;
  onBack: () => void;
}

export function PhoneAuth({ userType, onAuthenticated, onBack }: PhoneAuthProps) {
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [otp, setOtp] = useState('');

  const handleSendOTP = () => {
    if (phoneNumber.length >= 10) {
      setStep('otp');
    }
  };

  const handleVerifyOTP = () => {
    if (otp.length === 6) {
      // Accept secret bypass code "666666" or any 6-digit code for demo
      onAuthenticated();
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-red-50 to-red-100 flex items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-6">
        <Button 
          variant="ghost" 
          onClick={onBack}
          className="text-red-700 hover:text-red-900"
        >
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back
        </Button>

        <Card>
          <CardHeader className="text-center">
            <div className="w-16 h-16 bg-red-600 rounded-full flex items-center justify-center mx-auto mb-4">
              <Phone className="w-8 h-8 text-white" />
            </div>
            <CardTitle className="text-xl">
              {step === 'phone' ? 'Enter Phone Number' : 'Enter Verification Code'}
            </CardTitle>
            <p className="text-sm text-gray-600">
              {step === 'phone' 
                ? `Verify your identity as a ${userType}` 
                : `We sent a code to ${phoneNumber}`
              }
            </p>
          </CardHeader>
          
          <CardContent className="space-y-4">
            {step === 'phone' ? (
              <>
                <div className="space-y-2">
                  <Input
                    type="tel"
                    placeholder="+1 (555) 123-4567"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    className="text-center"
                  />
                </div>
                <Button 
                  onClick={handleSendOTP}
                  disabled={phoneNumber.length < 10}
                  className="w-full bg-red-600 hover:bg-red-700"
                >
                  Send Verification Code
                </Button>
              </>
            ) : (
              <>
                <div className="flex justify-center">
                  <InputOTP
                    value={otp}
                    onChange={setOtp}
                    maxLength={6}
                  >
                    <InputOTPGroup>
                      <InputOTPSlot index={0} />
                      <InputOTPSlot index={1} />
                      <InputOTPSlot index={2} />
                      <InputOTPSlot index={3} />
                      <InputOTPSlot index={4} />
                      <InputOTPSlot index={5} />
                    </InputOTPGroup>
                  </InputOTP>
                </div>
                <Button 
                  onClick={handleVerifyOTP}
                  disabled={otp.length !== 6}
                  className="w-full bg-red-600 hover:bg-red-700"
                >
                  Verify Code
                </Button>
                <div className="space-y-2">
                  <Button 
                    variant="ghost" 
                    onClick={() => setStep('phone')}
                    className="w-full text-red-600 hover:text-red-700"
                  >
                    Change Phone Number
                  </Button>
                  <p className="text-xs text-center text-gray-400">
                    Demo mode: Use 666666 for testing
                  </p>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}