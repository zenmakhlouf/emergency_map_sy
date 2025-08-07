import React from 'react';
import { MapPin, Navigation, Shield, Users, Flame, Heart, Car } from 'lucide-react';

interface MapMarker {
  id: string;
  type: 'incident' | 'responder' | 'citizen';
  subtype?: string;
  lat: number;
  lng: number;
  title: string;
  status?: string;
}

interface StaticMapProps {
  markers?: MapMarker[];
  center?: { lat: number; lng: number };
  zoom?: number;
  className?: string;
}

export function StaticMap({ 
  markers = [], 
  center = { lat: 40.7128, lng: -74.0060 }, 
  zoom = 14,
  className = "h-80" 
}: StaticMapProps) {
  // Convert lat/lng to pixel coordinates for our mock map
  const coordsToPixels = (lat: number, lng: number) => {
    const bounds = {
      north: center.lat + 0.01,
      south: center.lat - 0.01,
      east: center.lng + 0.01,
      west: center.lng - 0.01
    };
    
    const x = ((lng - bounds.west) / (bounds.east - bounds.west)) * 100;
    const y = ((bounds.north - lat) / (bounds.north - bounds.south)) * 100;
    
    return { x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) };
  };

  const getMarkerIcon = (marker: MapMarker) => {
    if (marker.type === 'incident') {
      switch (marker.subtype) {
        case 'fire': return <Flame className="w-4 h-4 text-red-600" />;
        case 'medical': return <Heart className="w-4 h-4 text-pink-600" />;
        case 'accident': return <Car className="w-4 h-4 text-orange-600" />;
        default: return <MapPin className="w-4 h-4 text-red-600" />;
      }
    } else if (marker.type === 'responder') {
      return <Shield className="w-4 h-4 text-blue-600" />;
    } else {
      return <Users className="w-4 h-4 text-green-600" />;
    }
  };

  const getMarkerColor = (marker: MapMarker) => {
    if (marker.type === 'incident') {
      switch (marker.subtype) {
        case 'fire': return 'bg-red-100 border-red-500';
        case 'medical': return 'bg-pink-100 border-pink-500';
        case 'accident': return 'bg-orange-100 border-orange-500';
        default: return 'bg-red-100 border-red-500';
      }
    } else if (marker.type === 'responder') {
      return 'bg-blue-100 border-blue-500';
    } else {
      return 'bg-green-100 border-green-500';
    }
  };

  return (
    <div className={`relative ${className} bg-gray-100 rounded-lg overflow-hidden border`}>
      {/* Mock OpenStreetMap Background */}
      <div className="absolute inset-0">
        {/* Grid pattern to simulate map tiles */}
        <svg className="w-full h-full opacity-20">
          <defs>
            <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#e5e7eb" strokeWidth="1"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>
        
        {/* Mock streets */}
        <div className="absolute inset-0">
          <div className="absolute top-1/4 left-0 right-0 h-1 bg-gray-300"></div>
          <div className="absolute top-1/2 left-0 right-0 h-1 bg-gray-300"></div>
          <div className="absolute top-3/4 left-0 right-0 h-1 bg-gray-300"></div>
          <div className="absolute left-1/4 top-0 bottom-0 w-1 bg-gray-300"></div>
          <div className="absolute left-1/2 top-0 bottom-0 w-1 bg-gray-300"></div>
          <div className="absolute left-3/4 top-0 bottom-0 w-1 bg-gray-300"></div>
        </div>

        {/* Mock buildings */}
        <div className="absolute top-6 left-8 w-12 h-8 bg-gray-400 rounded-sm opacity-40"></div>
        <div className="absolute top-12 right-16 w-10 h-12 bg-gray-400 rounded-sm opacity-40"></div>
        <div className="absolute bottom-16 left-12 w-14 h-6 bg-gray-400 rounded-sm opacity-40"></div>
        <div className="absolute bottom-8 right-8 w-8 h-10 bg-gray-400 rounded-sm opacity-40"></div>
        <div className="absolute top-20 left-1/3 w-16 h-12 bg-gray-400 rounded-sm opacity-40"></div>

        {/* Mock parks (green areas) */}
        <div className="absolute top-16 right-1/4 w-20 h-16 bg-green-200 rounded-lg opacity-60"></div>
        <div className="absolute bottom-12 left-1/4 w-16 h-12 bg-green-200 rounded-lg opacity-60"></div>
      </div>

      {/* Map Attribution */}
      <div className="absolute bottom-1 right-1 text-xs text-gray-500 bg-white/80 px-2 py-1 rounded">
        © OpenStreetMap
      </div>

      {/* Zoom Controls */}
      <div className="absolute top-4 right-4 flex flex-col bg-white rounded shadow-sm">
        <button className="p-2 hover:bg-gray-50 border-b text-gray-600">+</button>
        <button className="p-2 hover:bg-gray-50 text-gray-600">−</button>
      </div>

      {/* Center Marker (Current Location) */}
      <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
        <div className="w-4 h-4 bg-blue-600 rounded-full border-2 border-white shadow-lg animate-pulse"></div>
      </div>

      {/* Dynamic Markers */}
      {markers.map((marker) => {
        const position = coordsToPixels(marker.lat, marker.lng);
        return (
          <div
            key={marker.id}
            className="absolute transform -translate-x-1/2 -translate-y-1/2 z-10"
            style={{
              left: `${position.x}%`,
              top: `${position.y}%`
            }}
          >
            <div className={`w-8 h-8 rounded-full border-2 ${getMarkerColor(marker)} flex items-center justify-center shadow-lg hover:scale-110 transition-transform cursor-pointer`}>
              {getMarkerIcon(marker)}
            </div>
            
            {/* Tooltip */}
            <div className="absolute bottom-full mb-2 left-1/2 transform -translate-x-1/2 bg-black/80 text-white text-xs px-2 py-1 rounded whitespace-nowrap opacity-0 hover:opacity-100 transition-opacity pointer-events-none">
              {marker.title}
              {marker.status && (
                <div className="text-xs opacity-75">{marker.status}</div>
              )}
            </div>
          </div>
        );
      })}

      {/* Sample route line */}
      <svg className="absolute inset-0 pointer-events-none">
        <path
          d="M 30% 60% Q 50% 40% 70% 35%"
          stroke="#3b82f6"
          strokeWidth="3"
          fill="none"
          strokeDasharray="5,5"
          className="opacity-60"
        />
      </svg>

      {/* North Arrow */}
      <div className="absolute top-4 left-4 w-8 h-8 bg-white rounded-full shadow-sm flex items-center justify-center">
        <Navigation className="w-4 h-4 text-gray-600 transform rotate-0" />
      </div>
    </div>
  );
}

// Default sample markers for demo
export const sampleMarkers: MapMarker[] = [
  {
    id: '1',
    type: 'incident',
    subtype: 'fire',
    lat: 40.7130,
    lng: -74.0055,
    title: 'Building Fire',
    status: 'Active'
  },
  {
    id: '2',
    type: 'responder',
    lat: 40.7125,
    lng: -74.0065,
    title: 'Fire Truck #1',
    status: 'En Route'
  },
  {
    id: '3',
    type: 'incident',
    subtype: 'medical',
    lat: 40.7135,
    lng: -74.0045,
    title: 'Medical Emergency',
    status: 'Responding'
  },
  {
    id: '4',
    type: 'citizen',
    lat: 40.7120,
    lng: -74.0070,
    title: 'Reporter Location',
    status: 'Safe'
  }
];