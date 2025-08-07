import React, { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { 
  Shield, 
  MapPin, 
  MessageSquare, 
  User, 
  Clock,
  Navigation,
  Phone,
  Flame,
  Heart,
  Car,
  AlertCircle,
  CheckCircle,
  ArrowRight
} from 'lucide-react';

export function ResponderDashboard() {
  const [activeTab, setActiveTab] = useState('assigned');
  const [showReportModal, setShowReportModal] = useState(false);

  const availableReports = [
    {
      id: 3,
      type: 'fire',
      title: 'Warehouse Fire',
      location: '456 Industrial Blvd',
      reporter: 'Mike R.',
      severity: 'high',
      distance: '2.1 miles',
      time: '12 min ago',
      status: 'unassigned',
      description: 'Large warehouse fire, multiple units needed'
    },
    {
      id: 4,
      type: 'accident',
      title: 'Multi-vehicle Collision',
      location: 'Highway 101 & Exit 15',
      reporter: 'Highway Patrol',
      severity: 'medium',
      distance: '3.8 miles',
      time: '20 min ago',
      status: 'unassigned',
      description: 'Three car accident, potential injuries'
    }
  ];

  const assignedIncidents = [
    {
      id: 1,
      type: 'fire',
      title: 'Apartment Building Fire',
      location: '123 Main St, Apt 4B',
      reporter: 'John D.',
      severity: 'high',
      distance: '0.3 miles',
      time: '3 min ago',
      status: 'assigned',
      eta: '5 min'
    },
    {
      id: 2,
      type: 'medical',
      title: 'Elderly Person Collapsed',
      location: '789 Oak Avenue',
      reporter: 'Sarah M.',
      severity: 'medium',
      distance: '1.1 miles',
      time: '8 min ago',
      status: 'en-route',
      eta: '3 min'
    }
  ];

  const getIncidentIcon = (type: string) => {
    switch (type) {
      case 'fire': return <Flame className="w-4 h-4" />;
      case 'medical': return <Heart className="w-4 h-4" />;
      case 'accident': return <Car className="w-4 h-4" />;
      default: return <AlertCircle className="w-4 h-4" />;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'high': return 'bg-red-500';
      case 'medium': return 'bg-yellow-500';
      case 'low': return 'bg-green-500';
      default: return 'bg-gray-500';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-red-600 text-white p-4">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-lg font-semibold">Fire Department</h1>
            <p className="text-sm text-red-100">Officer Badge #1247</p>
          </div>
          <div className="text-right">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-2 h-2 bg-green-400 rounded-full" />
              <span className="text-sm">On Duty</span>
            </div>
            <Button size="sm" variant="secondary">
              <User className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="p-4 grid grid-cols-3 gap-3">
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-red-600">2</div>
            <div className="text-xs text-gray-600">Active</div>
          </CardContent>
        </Card>
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-green-600">7</div>
            <div className="text-xs text-gray-600">Today</div>
          </CardContent>
        </Card>
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-blue-600">98%</div>
            <div className="text-xs text-gray-600">Response</div>
          </CardContent>
        </Card>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="flex-1">
        <TabsContent value="assigned" className="m-0">
          <div className="p-4 space-y-4">
            {/* Assigned Incidents */}
            <div className="space-y-3">
              {assignedIncidents.map((incident) => (
                <Card key={incident.id} className="border-l-4 border-l-red-500">
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className={`w-8 h-8 rounded-full flex items-center justify-center ${getSeverityColor(incident.severity)} text-white`}>
                          {getIncidentIcon(incident.type)}
                        </div>
                        <div>
                          <h3 className="font-semibold text-gray-900">{incident.title}</h3>
                          <p className="text-sm text-gray-600">Reported by {incident.reporter}</p>
                        </div>
                      </div>
                      <Badge 
                        variant={incident.status === 'assigned' ? 'destructive' : 'default'}
                        className="text-xs"
                      >
                        {incident.status === 'assigned' ? 'NEW' : 'EN-ROUTE'}
                      </Badge>
                    </div>

                    <div className="space-y-2 mb-4">
                      <div className="flex items-center gap-2 text-sm text-gray-600">
                        <MapPin className="w-4 h-4" />
                        <span>{incident.location}</span>
                      </div>
                      <div className="flex items-center gap-4 text-sm text-gray-600">
                        <div className="flex items-center gap-1">
                          <Navigation className="w-4 h-4" />
                          <span>{incident.distance}</span>
                        </div>
                        <div className="flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          <span>ETA {incident.eta}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex gap-2">
                      <Button size="sm" variant="outline" className="flex-1">
                        <MessageSquare className="w-4 h-4 mr-1" />
                        Chat
                      </Button>
                      <Button size="sm" variant="outline" className="flex-1">
                        <Phone className="w-4 h-4 mr-1" />
                        Call
                      </Button>
                      <Button size="sm" className="flex-1 bg-red-600 hover:bg-red-700">
                        <Navigation className="w-4 h-4 mr-1" />
                        Navigate
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>

            {/* Quick Actions */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Quick Actions</CardTitle>
              </CardHeader>
              <CardContent className="grid grid-cols-2 gap-3">
                <Button variant="outline" className="h-16 flex-col gap-1">
                  <CheckCircle className="w-5 h-5" />
                  <span className="text-xs">Mark Available</span>
                </Button>
                <Button variant="outline" className="h-16 flex-col gap-1">
                  <MapPin className="w-5 h-5" />
                  <span className="text-xs">Update Location</span>
                </Button>
                <Button variant="outline" className="h-16 flex-col gap-1">
                  <Phone className="w-5 h-5" />
                  <span className="text-xs">Call Dispatch</span>
                </Button>
                <Button variant="outline" className="h-16 flex-col gap-1">
                  <AlertCircle className="w-5 h-5" />
                  <span className="text-xs">Report Issue</span>
                </Button>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="reports" className="m-0">
          <div className="p-4 space-y-4">
            <div className="flex justify-between items-center">
              <h2 className="font-semibold text-gray-900">Available Reports</h2>
              <Badge className="bg-blue-100 text-blue-800">
                {availableReports.length} Available
              </Badge>
            </div>

            <div className="space-y-3">
              {availableReports.map((report) => (
                <Card key={report.id} className="border-l-4 border-l-blue-500">
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className={`w-8 h-8 rounded-full flex items-center justify-center ${getSeverityColor(report.severity)} text-white`}>
                          {getIncidentIcon(report.type)}
                        </div>
                        <div>
                          <h3 className="font-semibold text-gray-900">{report.title}</h3>
                          <p className="text-sm text-gray-600">Reported by {report.reporter}</p>
                        </div>
                      </div>
                      <Badge variant="outline" className="text-xs border-blue-500 text-blue-700">
                        UNASSIGNED
                      </Badge>
                    </div>

                    <div className="space-y-2 mb-4">
                      <div className="flex items-center gap-2 text-sm text-gray-600">
                        <MapPin className="w-4 h-4" />
                        <span>{report.location}</span>
                      </div>
                      <div className="flex items-center gap-4 text-sm text-gray-600">
                        <div className="flex items-center gap-1">
                          <Navigation className="w-4 h-4" />
                          <span>{report.distance}</span>
                        </div>
                        <div className="flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          <span>{report.time}</span>
                        </div>
                      </div>
                      <p className="text-sm text-gray-700 bg-gray-50 p-2 rounded">
                        {report.description}
                      </p>
                    </div>

                    <div className="flex gap-2">
                      <Button 
                        size="sm" 
                        className="flex-1 bg-green-600 hover:bg-green-700"
                        onClick={() => alert(`Response request submitted for: ${report.title}`)}
                      >
                        <CheckCircle className="w-4 h-4 mr-1" />
                        Request to Respond
                      </Button>
                      <Button size="sm" variant="outline">
                        <Navigation className="w-4 h-4" />
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        </TabsContent>

        <TabsContent value="map" className="m-0">
          <div className="p-4">
            <Card>
              <CardContent className="p-0">
                <div className="h-80 bg-gradient-to-br from-red-100 to-orange-100 rounded-lg flex items-center justify-center relative overflow-hidden">
                  <div className="absolute inset-0 bg-gray-200/20" />
                  <div className="text-center z-10">
                    <MapPin className="w-12 h-12 text-red-600 mx-auto mb-2" />
                    <p className="text-gray-700">Incident Response Map</p>
                    <p className="text-sm text-gray-500">Real-time locations and routes</p>
                  </div>
                  
                  {/* Mock incident and responder markers */}
                  <div className="absolute top-20 left-16 w-4 h-4 bg-red-500 rounded-full animate-pulse" />
                  <div className="absolute bottom-24 right-20 w-4 h-4 bg-blue-500 rounded-full" />
                  <div className="absolute top-40 right-32 w-4 h-4 bg-yellow-500 rounded-full animate-pulse" />
                  
                  {/* Route line */}
                  <div className="absolute top-24 left-20 w-32 h-0.5 bg-blue-400 transform rotate-45" />
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="chat" className="m-0">
          <div className="p-4 space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Active Conversations</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-red-500 rounded-full flex items-center justify-center text-white">
                      <Flame className="w-5 h-5" />
                    </div>
                    <div>
                      <p className="font-medium">Building Fire - John D.</p>
                      <p className="text-sm text-gray-600">AI: "Fire department is 2 minutes away"</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <Badge className="mb-1">2 new</Badge>
                    <ArrowRight className="w-4 h-4 text-gray-400" />
                  </div>
                </div>
                
                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-pink-500 rounded-full flex items-center justify-center text-white">
                      <Heart className="w-5 h-5" />
                    </div>
                    <div>
                      <p className="font-medium">Medical Emergency - Sarah M.</p>
                      <p className="text-sm text-gray-600">You: "ETA 3 minutes"</p>
                    </div>
                  </div>
                  <ArrowRight className="w-4 h-4 text-gray-400" />
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Bottom Navigation */}
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200">
          <TabsList className="grid w-full grid-cols-4 h-16 bg-transparent">
            <TabsTrigger 
              value="assigned" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <AlertCircle className="w-5 h-5" />
              <span className="text-xs">Assigned</span>
            </TabsTrigger>
            <TabsTrigger 
              value="reports" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <Shield className="w-5 h-5" />
              <span className="text-xs">Reports</span>
            </TabsTrigger>
            <TabsTrigger 
              value="map" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <MapPin className="w-5 h-5" />
              <span className="text-xs">Map</span>
            </TabsTrigger>
            <TabsTrigger 
              value="chat" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <MessageSquare className="w-5 h-5" />
              <span className="text-xs">Chat</span>
            </TabsTrigger>
          </TabsList>
        </div>
      </Tabs>
    </div>
  );
}