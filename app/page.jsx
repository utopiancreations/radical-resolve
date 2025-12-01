"use client";

import React, { useState, useRef, useEffect } from 'react';
import { Send, User, Sparkles } from 'lucide-react';
import ReactMarkdown from 'react-markdown';

const RadicalResolveApp = () => {
    const [input, setInput] = useState('');
    const [messages, setMessages] = useState([]);
    const [isLoading, setIsLoading] = useState(false);
    const [dataCollectionConsent, setDataCollectionConsent] = useState(false);
    const messagesEndRef = useRef(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    const handleSend = async () => {
        if (!input.trim()) return;

        const userMessage = { role: 'user', content: input };
        const newMessages = [...messages, userMessage];

        setMessages(newMessages);
        setInput('');
        setIsLoading(true);

        try {
            const response = await fetch('/api/resolve', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ messages: newMessages, dataCollectionConsent }),
            });

            if (!response.ok) {
                throw new Error('Failed to resolve');
            }

            const data = await response.json();
            setMessages([...newMessages, data]);
        } catch (error) {
            console.error("Error resolving conflict:", error);
            // Optional: Add error message to chat
        } finally {
            setIsLoading(false);
        }
    };

    const handleKeyDown = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    };

    return (
        <div className="flex flex-col h-screen bg-stone-50 text-stone-800 font-sans">

            {/* Header */}
            <header className="bg-white border-b border-stone-200 p-4 flex items-center justify-between sticky top-0 z-10">
                <h1 className="text-xl font-bold tracking-tight text-stone-900 flex items-center gap-2">
                    <Sparkles size={20} className="text-stone-600" />
                    Radical Resolve
                </h1>

                {/* Consent Toggle */}
                <div className="flex items-center gap-2 text-xs text-stone-500">
                    <label htmlFor="consent-toggle" className="cursor-pointer select-none">
                        Help us learn?
                    </label>
                    <button
                        id="consent-toggle"
                        onClick={() => setDataCollectionConsent(!dataCollectionConsent)}
                        className={`w-8 h-4 rounded-full transition-colors relative ${dataCollectionConsent ? 'bg-emerald-500' : 'bg-stone-300'
                            }`}
                        title="Allow anonymized conversation data to be used for training."
                    >
                        <div className={`w-3 h-3 bg-white rounded-full absolute top-0.5 transition-transform ${dataCollectionConsent ? 'left-4.5' : 'left-0.5'
                            }`} style={{ left: dataCollectionConsent ? '18px' : '2px' }} />
                    </button>
                </div>
            </header>

            {/* Chat Area */}
            <div className="flex-1 overflow-y-auto p-4 space-y-6">
                {messages.length === 0 && (
                    <div className="flex flex-col items-center justify-center h-full text-stone-400 space-y-4">
                        <Sparkles size={48} strokeWidth={1} />
                        <p className="text-lg">What's on your mind?</p>
                        <p className="text-xs max-w-xs text-center opacity-70">
                            Your conversation is private unless you opt-in to help us learn.
                        </p>
                    </div>
                )}

                {messages.map((msg, index) => (
                    <div
                        key={index}
                        className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                    >
                        <div
                            className={`max-w-[85%] md:max-w-[70%] rounded-2xl p-4 shadow-sm ${msg.role === 'user'
                                ? 'bg-stone-900 text-white rounded-br-none'
                                : 'bg-white border border-stone-200 text-stone-800 rounded-bl-none'
                                }`}
                        >
                            {msg.role === 'assistant' ? (
                                <div className="prose prose-stone prose-sm max-w-none">
                                    <ReactMarkdown>{msg.content}</ReactMarkdown>
                                </div>
                            ) : (
                                <p className="whitespace-pre-wrap">{msg.content}</p>
                            )}
                        </div>
                    </div>
                ))}

                {isLoading && (
                    <div className="flex justify-start">
                        <div className="bg-white border border-stone-200 rounded-2xl rounded-bl-none p-4 shadow-sm flex items-center gap-2">
                            <div className="w-2 h-2 bg-stone-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                            <div className="w-2 h-2 bg-stone-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                            <div className="w-2 h-2 bg-stone-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                        </div>
                    </div>
                )}
                <div ref={messagesEndRef} />
            </div>

            {/* Input Area */}
            <div className="bg-white border-t border-stone-200 p-4">
                <div className="max-w-3xl mx-auto relative">
                    <textarea
                        className="w-full bg-stone-100 border-0 rounded-2xl pl-4 pr-12 py-3 resize-none focus:ring-2 focus:ring-stone-300 focus:outline-none max-h-32 min-h-[56px]"
                        placeholder="Type a message..."
                        rows={1}
                        value={input}
                        onChange={(e) => setInput(e.target.value)}
                        onKeyDown={handleKeyDown}
                        disabled={isLoading}
                    />
                    <button
                        onClick={handleSend}
                        disabled={!input.trim() || isLoading}
                        className="absolute right-2 bottom-2 p-2 bg-stone-900 text-white rounded-full hover:bg-stone-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                        <Send size={18} />
                    </button>
                </div>
                <p className="text-center text-xs text-stone-400 mt-2">
                    AI can make mistakes. Please use with discretion.
                </p>
            </div>
        </div>
    );
};

export default RadicalResolveApp;
