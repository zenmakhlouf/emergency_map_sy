import React, { useState, useRef, useEffect } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent } from './ui/card';
import { Badge } from './ui/badge';
import { 
  ArrowLeft, 
  Send, 
  Mic, 
  Camera, 
  MapPin,
  AlertTriangle,
  Bot,
  User,
  CheckCircle,
  FileText
} from 'lucide-react';

interface AIEmergencyChatProps {
  onBack: () => void;
  onReportComplete: (reportData: any) => void;
  onSwitchToManual: () => void;
}

interface Message {
  id: string;
  type: 'user' | 'ai' | 'system';
  content: string;
  timestamp: Date;
  classification?: {
    category: string;
    subcategory: string;
    severity: 'low' | 'medium' | 'high' | 'critical';
    confidence: number;
  };
}

export function AIEmergencyChat({ onBack, onReportComplete, onSwitchToManual }: AIEmergencyChatProps) {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      type: 'ai',
      content: "🚨 Emergency AI Assistant activated. I'm here to help you report your emergency quickly and accurately. Please describe what's happening in your own words - I'll handle the details.",
      timestamp: new Date()
    }
  ]);
  const [inputMessage, setInputMessage] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [reportClassified, setReportClassified] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const simulateAIClassification = (userMessage: string) => {
    // Simulate AI classification based on keywords
    let category = 'general';
    let subcategory = 'other';
    let severity: 'low' | 'medium' | 'high' | 'critical' = 'medium';

    const lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.includes('fire') || lowerMessage.includes('smoke') || lowerMessage.includes('burning')) {
      category = 'fire';
      subcategory = 'building_fire';
      severity = lowerMessage.includes('apartment') || lowerMessage.includes('building') ? 'high' : 'medium';
    } else if (lowerMessage.includes('accident') || lowerMessage.includes('crash') || lowerMessage.includes('collision')) {
      category = 'traffic';
      subcategory = 'vehicle_accident';
      severity = lowerMessage.includes('injured') ? 'high' : 'medium';
    } else if (lowerMessage.includes('heart') || lowerMessage.includes('chest') || lowerMessage.includes('breathing')) {
      category = 'medical';
      subcategory = 'cardiac_emergency';
      severity = 'critical';
    } else if (lowerMessage.includes('robbery') || lowerMessage.includes('theft') || lowerMessage.includes('stolen')) {
      category = 'crime';
      subcategory = 'theft';
      severity = 'medium';
    }

    return {
      category,
      subcategory,
      severity,
      confidence: Math.random() * 0.3 + 0.7 // 70-100% confidence
    };
  };

  const handleSendMessage = () => {
    if (!inputMessage.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      type: 'user',
      content: inputMessage,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);

    // Simulate AI processing delay
    setTimeout(() => {
      const classification = simulateAIClassification(inputMessage);
      
      const aiResponse: Message = {
        id: (Date.now() + 1).toString(),
        type: 'ai',
        content: `I've classified this as a ${classification.category.toUpperCase()} emergency (${Math.round(classification.confidence * 100)}% confidence). ${
          classification.severity === 'critical' 
            ? '🚨 This appears to be CRITICAL - dispatching immediate response!' 
            : classification.severity === 'high' 
            ? '⚠️ High priority incident detected - emergency services notified.'
            : 'Emergency services have been notified.'
        }\n\nCan you provide your exact location? I'm detecting you may be near your registered address.`,
        timestamp: new Date(),
        classification
      };

      setMessages(prev => [...prev, aiResponse]);
      setReportClassified(true);
    }, 1500);

    setInputMessage('');
  };

  const handleLocationConfirm = () => {
    const systemMessage: Message = {
      id: Date.now().toString(),
      type: 'system',
      content: '📍 Location confirmed: 123 Main Street, Downtown. Emergency responders have been notified and are en route.',
      timestamp: new Date()
    };

    setMessages(prev => [...prev, systemMessage]);

    setTimeout(() => {
      const finalMessage: Message = {
        id: (Date.now() + 1).toString(),
        type: 'ai',
        content: '✅ Your emergency report has been successfully submitted and classified. You\'ll now be connected to the incident chat where you can communicate with responders. Stay safe!',
        timestamp: new Date()
      };

      setMessages(prev => [...prev, finalMessage]);

      setTimeout(() => {
        const lastClassification = messages.find(m => m.classification)?.classification;
        onReportComplete({
          classification: lastClassification,
          location: '123 Main Street, Downtown',
          timestamp: new Date(),
          messages: [...messages, systemMessage, finalMessage]
        });
      }, 2000);
    }, 1000);
  };

  const getMessageIcon = (type: string) => {
    switch (type) {
      case 'ai': return <Bot className="w-4 h-4 text-blue-600" />;
      case 'user': return <User className="w-4 h-4 text-gray-600" />;
      case 'system': return <CheckCircle className="w-4 h-4 text-green-600" />;
      default: return null;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <div className="bg-red-600 text-white p-4 shadow-lg">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Button 
              size="sm" 
              variant="ghost" 
              onClick={onBack}
              className="text-white hover:bg-red-700 p-2"
            >
              <ArrowLeft className="w-5 h-5" />
            </Button>
            <div>
              <h1 className="font-semibold">Emergency AI Assistant</h1>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                <span className="text-xs text-red-100">Active</span>
              </div>
            </div>
          </div>
          <Button 
            size="sm" 
            variant="outline" 
            onClick={onSwitchToManual}
            className="text-red-600 border-white hover:bg-red-50"
          >
            <FileText className="w-4 h-4 mr-1" />
            Manual Form
          </Button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((message) => (
          <div
            key={message.id}
            className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-xs lg:max-w-md px-4 py-3 rounded-lg ${
              message.type === 'user'
                ? 'bg-blue-600 text-white'
                : message.type === 'system'
                ? 'bg-green-100 text-green-800 border border-green-200'
                : 'bg-white text-gray-900 border border-gray-200'
            }`}>
              <div className="flex items-start gap-2 mb-1">
                {getMessageIcon(message.type)}
                <span className="text-xs opacity-70">
                  {message.type === 'ai' ? 'AI Assistant' : message.type === 'system' ? 'System' : 'You'}
                </span>
              </div>
              <p className="text-sm leading-relaxed whitespace-pre-line">{message.content}</p>
              
              {message.classification && (
                <div className="mt-3 pt-3 border-t border-gray-200">
                  <div className="flex flex-wrap gap-2">
                    <Badge variant="destructive" className="text-xs">
                      {message.classification.category.toUpperCase()}
                    </Badge>
                    <Badge 
                      variant="outline" 
                      className={`text-xs ${
                        message.classification.severity === 'critical' ? 'border-red-500 text-red-700' :
                        message.classification.severity === 'high' ? 'border-orange-500 text-orange-700' :
                        'border-yellow-500 text-yellow-700'
                      }`}
                    >
                      {message.classification.severity.toUpperCase()}
                    </Badge>
                  </div>
                </div>
              )}
              
              <div className="text-xs opacity-50 mt-2">
                {message.timestamp.toLocaleTimeString()}
              </div>
            </div>
          </div>
        ))}

        {reportClassified && (
          <Card className="border-2 border-blue-200 bg-blue-50">
            <CardContent className="p-4">
              <div className="text-center space-y-3">
                <AlertTriangle className="w-8 h-8 text-blue-600 mx-auto" />
                <div>
                  <h3 className="font-semibold text-blue-900">Confirm Your Location</h3>
                  <p className="text-sm text-blue-700 mt-1">
                    To complete your emergency report, please confirm your location
                  </p>
                </div>
                <Button 
                  onClick={handleLocationConfirm}
                  className="w-full bg-blue-600 hover:bg-blue-700"
                >
                  <MapPin className="w-4 h-4 mr-2" />
                  Confirm Location: 123 Main Street
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="bg-white border-t border-gray-200 p-4">
        <div className="flex items-center gap-2">
          <div className="flex-1 relative">
            <Input
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              placeholder="Describe your emergency..."
              onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
              className="pr-20"
            />
            <div className="absolute right-2 top-1/2 -translate-y-1/2 flex gap-1">
              <Button
                size="sm"
                variant="ghost"
                onClick={() => setIsRecording(!isRecording)}
                className={`p-1 ${isRecording ? 'text-red-600' : 'text-gray-400'}`}
              >
                <Mic className="w-4 h-4" />
              </Button>
              <Button
                size="sm"
                variant="ghost"
                className="p-1 text-gray-400"
              >
                <Camera className="w-4 h-4" />
              </Button>
            </div>
          </div>
          <Button 
            onClick={handleSendMessage}
            disabled={!inputMessage.trim()}
            className="bg-red-600 hover:bg-red-700"
          >
            <Send className="w-4 h-4" />
          </Button>
        </div>
        
        <div className="flex justify-center mt-2">
          <Badge variant="outline" className="text-xs text-gray-500">
            🤖 AI-powered emergency classification • Fast response
          </Badge>
        </div>
      </div>
    </div>
  );
}