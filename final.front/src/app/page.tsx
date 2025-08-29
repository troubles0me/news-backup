'use client';

import { useState, useRef, useEffect } from 'react';

// --- 타입 정의 ---
type Message = {
  sender: 'user' | 'ai';
  text: string;
};

type QuizQuestion = {
  question: string;
  options: string[];
  answer: string;
};

type LearnedEntry = {
  word: string;
  definition: string;
};

export default function Home() {
  const chatWindowRef = useRef<HTMLDivElement>(null);
  
  // --- State 정의 ---
  const [url, setUrl] = useState('');
  const [article, setArticle] = useState({ title: '', content: '' });
  const [isLoading, setIsLoading] = useState(false);
  const [chatInput, setChatInput] = useState('');
  const [chatMessages, setChatMessages] = useState<Message[]>([]);
  const [learnedEntries, setLearnedEntries] = useState<LearnedEntry[]>([]);
  const [quiz, setQuiz] = useState<QuizQuestion | null>(null);
  const [quizFeedback, setQuizFeedback] = useState('');
  const [quizzedWords, setQuizzedWords] = useState<string[]>([]);
  const [isQuizLoading, setIsQuizLoading] = useState(false);
  const [incorrectEntries, setIncorrectEntries] = useState<LearnedEntry[]>([]);
  const [isReviewMode, setIsReviewMode] = useState(false);
  const [reviewQuizzedWords, setReviewQuizzedWords] = useState<string[]>([]); // 오답 복습 세션용 출제 기록

  // --- 함수 정의 ---
  const handleScrape = async () => {
    if (!url) {
      alert('기사 URL을 입력해주세요.');
      return;
    }
    setIsLoading(true);
    setArticle({ title: '', content: '기사를 가져오는 중입니다...' });

    try {
      const response = await fetch('http://20.41.113.134:8000/api/scrape', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url }),
      });

      console.log('Scrape API Response status:', response.status);
      console.log('Scrape API Response headers:', response.headers);

      if (response.ok) {
        const data = await response.json();
        console.log('Scrape API Response data:', data);
        setArticle(data);
      } else {
        const errorText = await response.text();
        console.error('Scrape API Error Response:', errorText);
        setArticle({ title: '오류', content: `기사를 가져오는 데 실패했습니다. (${response.status}): ${errorText}` });
      }
    } catch (error) {
      console.error('Scrape Fetch Error:', error);
      setArticle({ title: '오류', content: `네트워크 오류: ${error instanceof Error ? error.message : '알 수 없는 오류'}` });
    }
    setIsLoading(false);
  };

  const handleChatSubmit = async () => {
    if (!chatInput.trim()) return;
    const userMessage: Message = { sender: 'user', text: chatInput };
    setChatMessages(prev => [...prev, userMessage]);
    const currentChatInput = chatInput;
    setChatInput('');

    try {
      const response = await fetch('http://20.41.113.134:8000/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ word: currentChatInput, context: article.content }),
      });

      console.log('API Response status:', response.status);
      console.log('API Response headers:', response.headers);

      if (response.ok) {
          const data = await response.json();
          console.log('API Response data:', data);
          setChatMessages(prev => [...prev, { sender: 'ai', text: data.answer }]);
          setLearnedEntries(prev => {
            const isAlreadyLearned = prev.some(entry => entry.word === currentChatInput);
            if (isAlreadyLearned) {
              return prev.map(entry => 
                entry.word === currentChatInput ? { ...entry, definition: data.answer } : entry
              );
            } else {
              return [...prev, { word: currentChatInput, definition: data.answer }];
            }
          });
      } else {
          const errorText = await response.text();
          console.error('API Error Response:', errorText);
          setChatMessages(prev => [...prev, { sender: 'ai', text: `API 오류 (${response.status}): ${errorText}` }]);
      }
    } catch (error) {
      console.error('Fetch Error:', error);
      setChatMessages(prev => [...prev, { sender: 'ai', text: `네트워크 오류: ${error instanceof Error ? error.message : '알 수 없는 오류'}` }]);
    }
  };

  const fetchNextProblem = async (reviewMode: boolean) => {
    setIsQuizLoading(true);
    setQuizFeedback('');

    const sourceEntries = reviewMode ? incorrectEntries : learnedEntries;
    const currentQuizzedList = reviewMode ? reviewQuizzedWords : quizzedWords;
    
    const availableEntries = sourceEntries.filter(entry => !currentQuizzedList.includes(entry.word));

    if (availableEntries.length < 1) {
      const message = reviewMode 
        ? "오답 복습을 완료했습니다!" 
        : "모든 단어에 대한 퀴즈를 완료했습니다!";
      alert(message);
      
      setQuiz(null);
      setIsReviewMode(false);

    } else {
      const response = await fetch('http://20.41.113.134:8000/api/quiz', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ entries: availableEntries }),
      });

      if (response.ok) {
        const quizData = await response.json();
        if (quizData.error) {
          alert(quizData.error);
        } else {
          setQuiz(quizData);
          if (reviewMode) {
            setReviewQuizzedWords(prev => [...prev, quizData.question]);
          } else {
            setQuizzedWords(prev => [...prev, quizData.question]);
          }
        }
      } else {
        alert('퀴즈를 가져오는 데 실패했습니다.');
        setQuiz(null);
      }
    }
    setIsQuizLoading(false);
  };
  
  const handleStartQuiz = () => {
    if (learnedEntries.length < 1) {
      alert('퀴즈를 풀려면 최소 1개의 단어를 학습해야 합니다.');
      return;
    }
    setIsReviewMode(false);
    setIncorrectEntries([]);
    setIsQuizLoading(true);
    fetchNextProblem(false);
  };

  const handleStartReview = () => {
    if (incorrectEntries.length < 1) {
      alert("틀린 문제가 없습니다.");
      return;
    }
    setIsReviewMode(true);
    setReviewQuizzedWords([]);
    setIsQuizLoading(true);
    fetchNextProblem(true);
  };

  const handleAnswerSelect = (selectedOption: string) => {
    if (!quiz) return;
    if (selectedOption === quiz.answer) {
      setQuizFeedback('정답입니다! 🎉');
      if (isReviewMode) {
        setIncorrectEntries(prev => prev.filter(entry => entry.word !== quiz.question));
      }
    } else {
      setQuizFeedback(`오답입니다. 정답은 "${quiz.answer}"입니다.`);
      if (!isReviewMode) {
        const incorrectEntry = learnedEntries.find(entry => entry.word === quiz.question);
        if (incorrectEntry) {
          setIncorrectEntries(prev => {
            if (prev.some(e => e.word === incorrectEntry.word)) return prev;
            return [...prev, incorrectEntry];
          });
        }
      }
    }
  };

  // '기사로 돌아가기' 또는 '나가기' 버튼을 누르는 함수 (수정됨)
  const handleQuitQuiz = () => {
    setQuiz(null);
    setQuizFeedback('');
    setIsReviewMode(false);
    // 퀴즈 기록을 초기화하여 isQuizOver가 false가 되도록 함
    setQuizzedWords([]); 
    setIncorrectEntries([]);
  };
  
  const handleResetQuiz = () => {
    setQuizzedWords([]);
    setReviewQuizzedWords([]);
    setIncorrectEntries([]);
    alert('퀴즈 기록이 초기화되었습니다.');
  };

  const handleReturnToStart = () => {
    setUrl('');
    setArticle({ title: '', content: '' });
    setChatMessages([]);
    setLearnedEntries([]);
    setQuizzedWords([]);
    setIncorrectEntries([]);
    setQuiz(null);
    setIsReviewMode(false);
  };

  useEffect(() => {
    if (chatWindowRef.current) {
      chatWindowRef.current.scrollTop = chatWindowRef.current.scrollHeight;
    }
  }, [chatMessages]);

  const isQuizOver = learnedEntries.length > 0 && learnedEntries.length === quizzedWords.length;

  return (
    <div style={styles.mainContainer}>
      {/* 왼쪽 영역 */}
      <div style={styles.leftPanel}>
        {quiz || isQuizLoading ? (
          <div style={styles.quizContainer}>
            <div style={styles.quizHeader}>
              <h2>✍️ {isReviewMode ? '오답 복습 퀴즈' : '단어 복습 퀴즈'}</h2>
              <button onClick={handleQuitQuiz} style={styles.quitQuizButton}>나가기</button>
            </div>
            {isQuizLoading ? (
              <p style={styles.quizLoadingText}>
                {isReviewMode ? "오답 문제 불러오는중....." : "퀴즈를 생성하는 중...."}
              </p>
            ) : (
              quiz && (
                <>
                  <p style={styles.quizInstruction}>다음 단어의 뜻으로 알맞은 것을 고르세요.</p>
                  <h3 style={styles.quizWord}>{quiz.question}</h3>
                  <div style={styles.optionsContainer}>
                    {quiz.options.map((option, index) => (
                      <button 
                        key={index} 
                        style={styles.optionButton}
                        onClick={() => handleAnswerSelect(option)}
                        disabled={!!quizFeedback}
                      >
                        {option}
                      </button>
                    ))}
                  </div>
                  {quizFeedback && (
                    <div style={styles.quizFeedback}>
                      <p>{quizFeedback}</p>
                      <button style={styles.nextQuizButton} onClick={() => fetchNextProblem(isReviewMode)}>다음 문제</button>
                    </div>
                  )}
                </>
              )
            )}
          </div>
        ) : isQuizOver ? (
          <div style={styles.quizResultContainer}>
            <h2>🎉 퀴즈 완료!</h2>
            <p>총 {learnedEntries.length}개 단어 중 <span style={{color: '#22c55e'}}>{learnedEntries.length - incorrectEntries.length}개</span>를 맞혔습니다.</p>
            <div style={styles.resultActionsContainer}>
              {incorrectEntries.length > 0 && (
                <button style={styles.startReviewButton} onClick={handleStartReview}>
                  오답 다시 풀기 ({incorrectEntries.length}개)
                </button>
              )}
              <button style={styles.returnToArticleButton} onClick={handleQuitQuiz}>기사로 돌아가기</button>
            </div>
          </div>
        ) : article.title ? (
          <div style={{position: 'relative', paddingRight: '20px'}}>
            <button onClick={handleReturnToStart} style={styles.returnToStartButton}>
              새로운 기사로 시작하기
            </button>
            <h2>[제목]: {article.title}</h2>
            <p style={styles.articleContent}>[본문]:<br />{article.content}</p>
          </div>
        ) : (
          <div style={styles.urlInputContainer}>
            <textarea 
              style={styles.urlInputBox}
              placeholder="이곳에 매일경제 기사 URL을 복사하여 넣으세요...."
              value={url}
              onChange={(e) => setUrl(e.target.value)}
            />
            <button style={styles.startButton} onClick={handleScrape} disabled={isLoading}>
              <span>{isLoading ? '로딩중...' : '시작'}</span>
            </button>
          </div>
        )}
      </div>

      {/* 오른쪽 영역 */}
      <div style={styles.rightPanel}>
        {learnedEntries.length > 0 && !quiz && !isQuizOver && (
          <button style={styles.startQuizButton} onClick={handleStartQuiz}>
            퀴즈 풀기 ({learnedEntries.length - quizzedWords.length}개 남음)
          </button>
        )}
        {quizzedWords.length > 0 && !quiz && (
          <button style={styles.resetQuizButton} onClick={handleResetQuiz}>
            퀴즈 기록 초기화
          </button>
        )}
        <div ref={chatWindowRef} style={styles.chatWindow}>
          {chatMessages.length === 0 && <p style={{color: '#888'}}>기사를 불러온 후, 궁금한 단어를 질문해보세요!</p>}
          {chatMessages.map((msg, index) => (
            <p key={index} style={msg.sender === 'user' ? styles.userMessage : styles.aiMessage}>{msg.text}</p>
          ))}
        </div>
        <div style={styles.chatInputArea}>
          <input type="text" style={styles.chatInput} value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleChatSubmit()} placeholder="궁금한 단어를 입력하세요..." />
          <button style={styles.sendButton} onClick={handleChatSubmit}>전송</button>
        </div>
      </div>
    </div>
  );
}

// --- 스타일 객체 ---
const styles = {
  mainContainer: { display: 'flex', height: '100vh', background: '#f4f6fa' },
  leftPanel: { flex: 7, padding: '40px', overflowY: 'auto', borderRight: '2px solid #e0e0e0', background: '#fff' },
  rightPanel: { flex: 3, display: 'flex', flexDirection: 'column', padding: '24px', backgroundColor: '#f5f7fb' },
  urlInputContainer: { display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', height: '100%' },
  urlInputBox: { width: '85%', height: '180px', border: '2px solid #b3c2e0', padding: '18px', fontSize: '1.05rem', resize: 'none', borderRadius: '10px', background: '#f8fbff' },
  startButton: { width: '110px', height: '48px', marginTop: '18px', backgroundColor: '#2563eb', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: 600, fontSize: '1.05rem',display: 'flex',alignItems: 'center',justifyContent: 'center'},
  articleContent: { whiteSpace: 'pre-wrap', lineHeight: 1.8, fontSize: '1.08rem', color: '#222' },
  chatWindow: { flexGrow: 1, border: '1px solid #b3c2e0', marginBottom: '12px', padding: '12px', overflowY: 'auto', backgroundColor: '#fff', borderRadius: '8px' },
  chatInputArea: { display: 'flex', gap: '8px' },
  chatInput: { flexGrow: 1, padding: '10px', border: '1px solid #b3c2e0', borderRadius: '8px', fontSize: '1rem' },
  sendButton: { padding: '10px 16px', border: 'none', backgroundColor: '#22c55e', color: 'white', borderRadius: '8px', fontWeight: 600, fontSize: '1rem', cursor: 'pointer' },
  userMessage: { textAlign: 'right', color: '#2563eb', margin: '6px', fontWeight: 500 },
  aiMessage: { textAlign: 'left', margin: '6px', color: '#333', background: '#eef2fa', borderRadius: '6px', padding: '6px 10px', display: 'inline-block' },
  startQuizButton: {
    marginBottom: '10px',
    padding: '12px',
    width: '100%',
    border: 'none',
    borderRadius: '8px',
    backgroundColor: '#ff9f43',
    color: 'white',
    fontSize: '1rem',
    fontWeight: '600',
    cursor: 'pointer'
  },
  resetQuizButton: {
    marginBottom: '10px',
    padding: '10px',
    width: '100%',
    border: '1px solid #6c757d',
    borderRadius: '8px',
    backgroundColor: 'transparent',
    color: '#6c757d',
    fontSize: '0.9rem',
    fontWeight: '600',
    cursor: 'pointer'
  },
  quizContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    textAlign: 'center',
    position: 'relative',
  },
  quizHeader: {
    width: '100%',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    position: 'relative',
  },
  quitQuizButton: {
    position: 'absolute',
    top: 0,
    right: 0,
    background: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    padding: '8px 16px',
    cursor: 'pointer',
    fontSize: '0.9rem',
  },
  quizInstruction: {
    fontSize: '1.2rem',
    color: '#555',
    marginBottom: '10px'
  },
  quizWord: {
    fontSize: '2.5rem',
    fontWeight: 'bold',
    color: '#2563eb',
    margin: '10px 0 25px 0',
    padding: '10px 20px',
    backgroundColor: '#eef2fa',
    borderRadius: '8px'
  },
  optionsContainer: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '15px',
    width: '80%'
  },
  optionButton: {
    padding: '20px',
    fontSize: '1.1rem',
    border: '2px solid #ddd',
    borderRadius: '8px',
    background: '#fff',
    cursor: 'pointer'
  },
  quizFeedback: {
    marginTop: '20px',
    fontSize: '1.2rem',
    fontWeight: 'bold'
  },
  nextQuizButton: {
    marginTop: '10px',
    padding: '10px 20px',
    border: 'none',
    borderRadius: '8px',
    backgroundColor: '#2563eb',
    color: 'white',
    fontSize: '1rem',
    cursor: 'pointer'
  },
  quizLoadingText: {
    fontSize: '1.5rem',
    color: '#555',
    fontWeight: '600'
  },
  quizResultContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    textAlign: 'center',
  },
  resultActionsContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '15px',
    marginTop: '30px'
  },
  startReviewButton: {
    padding: '15px 30px',
    border: 'none',
    borderRadius: '8px',
    backgroundColor: '#e11d48',
    color: 'white',
    fontSize: '1.1rem',
    fontWeight: '600',
    cursor: 'pointer'
  },
  returnToArticleButton: {
    background: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    padding: '15px 30px',
    cursor: 'pointer',
    fontSize: '1.1rem',
    fontWeight: '600',
  },
  returnToStartButton: {
    position: 'absolute',
    top: '40px',
    right: '40px',
    background: '#0d6efd',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    padding: '10px 18px',
    cursor: 'pointer',
    fontSize: '1rem',
    fontWeight: '600',
  }
} as const;
