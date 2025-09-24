from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from app.ws.manager import connection_manager
from app.api import boards

app = FastAPI(title="Affinity Diagram API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(boards.router, prefix="/api/boards", tags=["boards"])

@app.get("/")
async def root():
    return {
        "message": "Affinity Diagram API",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/health",
        "websocket": "/ws/board/{board_id}"
    }

@app.get("/health")
async def health():
    return {"status": "ok"}
# In-memory realtime board state (simple volatile store)
class BoardRealtimeState:
    def __init__(self):
        self.notes = []  # list of dicts {id,text,color,x,y,isPinned}
        self.gridMode = 'none'
        self.sectionTitles = {
            'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': '',
            'left': '', 'right': '', 'top': '', 'bottom': ''
        }
        self.version = 0

    def snapshot(self):
        return {
            'notes': self.notes,
            'gridMode': self.gridMode,
            'sectionTitles': self.sectionTitles,
            'version': self.version
        }

board_states: dict[str, BoardRealtimeState] = {}

def get_board_state(board_id: str) -> BoardRealtimeState:
    if board_id not in board_states:
        board_states[board_id] = BoardRealtimeState()
    return board_states[board_id]

@app.websocket("/ws/board/{board_id}")
async def board_ws(websocket: WebSocket, board_id: str):
    state = get_board_state(board_id)
    await connection_manager.connect(board_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            etype = data.get('type')

            # Sync request: respond only to requester
            if etype == 'sync.request':
                await websocket.send_json({
                    'type': 'sync.state',
                    'notes': state.notes,
                    'gridMode': state.gridMode,
                    'sectionTitles': state.sectionTitles,
                    'version': state.version
                })
                continue

            mutated = False
            broadcast_payload = None

            if etype == 'note.add':
                note = data.get('note')
                if note and not any(n['id'] == note['id'] for n in state.notes):
                    state.notes.append({
                        'id': note['id'], 'text': note.get('text',''), 'color': note.get('color','yellow'),
                        'x': note.get('x',0), 'y': note.get('y',0), 'isPinned': note.get('isPinned', False)
                    })
                    mutated = True
                    broadcast_payload = {'type':'note.add','note': note}
            elif etype == 'note.move':
                nid = data.get('id')
                for n in state.notes:
                    if n['id'] == nid:
                        n['x'] = data.get('x', n['x'])
                        n['y'] = data.get('y', n['y'])
                        mutated = True
                        broadcast_payload = {'type':'note.move','id': nid, 'x': n['x'], 'y': n['y']}
                        break
            elif etype == 'note.update':
                nid = data.get('id')
                for n in state.notes:
                    if n['id'] == nid:
                        n['text'] = data.get('text', n['text'])
                        mutated = True
                        broadcast_payload = {'type':'note.update','id': nid, 'text': n['text']}
                        break
            elif etype == 'note.pin':
                nid = data.get('id')
                for n in state.notes:
                    if n['id'] == nid:
                        n['isPinned'] = bool(data.get('isPinned', n['isPinned']))
                        mutated = True
                        broadcast_payload = {'type':'note.pin','id': nid,'isPinned': n['isPinned']}
                        break
            elif etype == 'board.gridMode':
                mode = data.get('mode')
                if mode in ['none','2-col','2-row','4-grid']:
                    state.gridMode = mode
                    mutated = True
                    broadcast_payload = {'type':'board.gridMode','mode': mode}
            elif etype == 'board.sectionTitle':
                section = data.get('section')
                title = data.get('title','')
                if section in state.sectionTitles:
                    state.sectionTitles[section] = title
                    mutated = True
                    broadcast_payload = {'type':'board.sectionTitle','section': section,'title': title}
            elif etype == 'board.reset':
                # 전체 상태 초기화
                state.notes = []
                state.gridMode = 'none'
                state.sectionTitles = {
                    'topLeft': '', 'topRight': '', 'bottomLeft': '', 'bottomRight': '',
                    'left': '', 'right': '', 'top': '', 'bottom': ''
                }
                mutated = True
                # reset 후 전체 스냅샷 전송을 위해 broadcast_payload를 sync.state 형태로 사용
                broadcast_payload = {
                    'type': 'sync.state',
                    'notes': state.notes,
                    'gridMode': state.gridMode,
                    'sectionTitles': state.sectionTitles
                }

            if mutated:
                state.version += 1
                # Include version in broadcast for client-side LWW decision if expanded later
                if broadcast_payload:
                    broadcast_payload['version'] = state.version
                    await connection_manager.broadcast(board_id, broadcast_payload, sender=websocket)
            else:
                # Unknown event -> echo as-is (fallback) without mutation
                pass
    except WebSocketDisconnect:
        connection_manager.disconnect(board_id, websocket)
